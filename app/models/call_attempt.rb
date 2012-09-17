require Rails.root.join("lib/twilio_lib")
require Rails.root.join("lib/redis_connection")

class CallAttempt < ActiveRecord::Base

  include Rails.application.routes.url_helpers
  include LeadEvents
  include CallPayment
  belongs_to :voter
  belongs_to :campaign
  belongs_to :caller
  belongs_to :caller_session
  has_one :transfer_attempt
  belongs_to :call
  has_many :answers
  has_many :note_responses

  scope :dial_in_progress, where('call_end is null')
  scope :not_wrapped_up, where('wrapup_time is null')
  scope :for_campaign, lambda { |campaign| {:conditions => ["campaign_id = ?", campaign.id]}  unless campaign.nil?}
  scope :for_caller, lambda { |caller| {:conditions => ["caller_id = ?", caller.id]}  unless caller.nil?}

  scope :for_status, lambda { |status| {:conditions => ["call_attempts.status = ?", status]} }
  scope :between, lambda { |from, to| where(:created_at => (from..to)) }
  scope :without_status, lambda { |statuses| {:conditions => ['status not in (?)', statuses]} }
  scope :with_status, lambda { |statuses| {:conditions => ['status in (?)', statuses]} }
  scope :results_not_processed, lambda { where(:voter_response_processed => "0", :status => Status::SUCCESS).where('wrapup_time is not null') }
  scope :debit_not_processed, where(debited: "0").where('call_end is not null')



  def report_recording_url
    "#{self.recording_url.gsub("api.twilio.com", "recordings.impactdialing.com")}.mp3" if recording_url
  end


  def duration
    return nil unless connecttime
    ((call_end || Time.now) - connecttime).to_i
  end


  def duration_wrapped_up
    ((wrapup_time || Time.now) - (self.connecttime || Time.now)).to_i
  end

  def time_to_wrapup
    ((wrapup_time || Time.now) - (self.call_end || Time.now)).to_i
  end

  def duration_rounded_up
    ((duration || 0) / 60.0).ceil
  end

  def minutes_used
    return 0 if self.tDuration.blank?
    (self.tDuration/60.0).ceil
  end

  def client
    campaign.client
  end

  def self.wrapup_calls(caller_id)
    not_wrapped_up = CallAttempt.not_wrapped_up.find_all_by_caller_id(caller_id)
    not_wrapped_up.each {|call_attempt| call_attempt.update_attributes(wrapup_time: Time.now)}
  end

  def connect_call
    redis_call_attempt = RedisCallAttempt.read(self.id)
    redis_voter = RedisVoter.read(redis_call_attempt['voter_id'])
    RedisCallAttempt.connect_call(self.id, redis_voter["caller_id"], redis_voter["caller_session_id"])
    RedisConnection.common_connection.rpush('connected_call_notification', {call_attempt: self.id, event: "call_connected"}.to_json)
  end

  def abandon_call
    $redis_call_flow_connection.pipelined do
      RedisCallAttempt.abandon_call(self.id)
      RedisVoter.abandon_call(voter.id)
    end
    RedisConnection.common_connection.rpush('notconnected_call_notification', {call_attempt: self.id, event: "call_abandoned"}.to_json)
  end
      
    
  def connect_lead_to_caller
    RedisVoter.connect_lead_to_caller(voter.id, campaign.id, self.id)
  end

  def caller_not_available?
    connect_lead_to_caller
    RedisVoter.could_not_connect_to_available_caller?(voter.id) 
  end

  def caller_available?
    !caller_not_available?
  end


  def end_answered_call
    $redis_call_flow_connection.pipelined do
      RedisCallAttempt.end_answered_call(self.id)
      RedisVoter.end_answered_call(voter.id)
    end
    RedisConnection.common_connection.rpush('connected_call_notification', {call_attempt: self.id, event: "end_answered_call"}.to_json)
  end

  def process_answered_by_machine
    status = RedisCampaign.call_status_use_recordings(campaign.id)
    $redis_call_flow_connection.pipelined do
      RedisCallAttempt.answered_by_machine(self.id, status)
      RedisVoter.answered_by_machine(voter.id, status)
    end
    RedisConnection.common_connection.rpush('notconnected_call_notification', {call_attempt: self.id, event: "answered_by_machine"}.to_json)    
  end

  def end_answered_by_machine
    $redis_call_flow_connection.pipelined do
      RedisCallAttempt.end_answered_by_machine(self.id)
      RedisVoter.end_answered_by_machine(voter.id)
    end
    RedisConnection.common_connection.rpush('notconnected_call_notification', {call_attempt: self.id, event: "end_answered_by_machine"}.to_json)    
  end


  def end_unanswered_call
    status = CallAttempt::Status::MAP[call.call_status]
    $redis_call_flow_connection.pipelined do
      RedisCallAttempt.end_unanswered_call(self.id, status)
      RedisVoter.end_unanswered_call(voter.id, status)
    end
    RedisConnection.common_connection.rpush('notconnected_call_notification', {call_attempt: self.id, event: "end_unanswered_call"}.to_json)
  end

  def end_running_call(account=TWILIO_ACCOUNT, auth=TWILIO_AUTH)
    call_sid = RedisCallAttempt.read(self.id)["sid"]
    EM.synchrony {
      t = TwilioLib.new(account, auth)    
      deferrable = t.end_call(call_sid)              
      deferrable.callback {}
      deferrable.errback { |error| }
    }
  end

  def not_wrapped_up?
    wrapup_time.nil?
  end

  def disconnect_call
    $redis_call_flow_connection.pipelined do
      RedisCallAttempt.disconnect_call(self.id, call.recording_duration, call.recording_url)
      RedisVoter.set_status(voter.id, CallAttempt::Status::SUCCESS)
      RedisVoter.read(voter.id)["caller_session_id"]
    end    
  end

  def schedule_for_later(date)
    scheduled_date = DateTime.strptime(date, "%m/%d/%Y %H:%M").to_time
    $redis_call_flow_connection.pipelined do    
      RedisCallAttempt.schedule_for_later(self.id, scheduled_date)
      RedisVoter.schedule_for_later(voter.id, scheduled_date)
    end
  end

  def wrapup_now
    RedisCallAttempt.wrapup(self.id)    
  end

  def self.time_on_call(caller, campaign, from, to)
    CallAttempt.for_campaign(campaign).for_caller(caller).between(from, to).without_status([CallAttempt::Status::VOICEMAIL, CallAttempt::Status::ABANDONED]).sum('TIMESTAMPDIFF(SECOND ,connecttime,call_end)').to_i
  end

  def self.time_in_wrapup(caller, campaign, from, to)
    CallAttempt.for_campaign(campaign).for_caller(caller).between(from, to).without_status([CallAttempt::Status::VOICEMAIL, CallAttempt::Status::ABANDONED]).sum('TIMESTAMPDIFF(SECOND ,call_end,wrapup_time)').to_i
  end

  def self.lead_time(caller, campaign, from, to)
    CallAttempt.for_campaign(campaign).for_caller(caller).between(from, to).without_status([CallAttempt::Status::VOICEMAIL, CallAttempt::Status::ABANDONED]).sum('ceil(TIMESTAMPDIFF(SECOND ,connecttime,call_end)/60)').to_i
  end

  def call_not_connected?
    connecttime.nil? || call_end.nil?
  end

  def call_time
  ((call_end - connecttime)/60).ceil
  end

  def redis_caller_session
    RedisCallAttempt.caller_session_id(self.id)
  end 
  
  def caller_session_key
    RedisCallerSession.caller_session(redis_caller_session)['session_key']
  end
  
  
  module Status
    VOICEMAIL = 'Message delivered'
    SUCCESS = 'Call completed with success.'
    INPROGRESS = 'Call in progress'
    NOANSWER = 'No answer'
    ABANDONED = "Call abandoned"
    BUSY = "No answer busy signal"
    FAILED = "Call failed"
    HANGUP = "Hangup or answering machine"
    READY = "Call ready to dial"
    CANCELLED = "Call cancelled"
    SCHEDULED = 'Scheduled for later'
    RINGING = "Ringing"

    MAP = {'in-progress' => INPROGRESS, 'completed' => SUCCESS, 'busy' => BUSY, 'failed' => FAILED, 'no-answer' => NOANSWER, 'canceled' => CANCELLED}
    ALL = MAP.values
    RETRY = [NOANSWER, BUSY, FAILED]
    ANSWERED =  [INPROGRESS, SUCCESS]
  end

  def redirect_caller(account=TWILIO_ACCOUNT, auth=TWILIO_AUTH)
    puts "redirect caller"
    session_id = redis_caller_session
    puts session_id
    unless session_id.nil?
      session = CallerSession.find(session_id)
      EM.synchrony {
        t = TwilioLib.new(account, auth)
        deferrable = t.redirect_call(session.sid, flow_caller_url(session.caller, :host => Settings.host, :port => Settings.port, session_id: session.id, event: "start_conf"))
        deferrable.callback {}
        deferrable.errback { |error| }
      }
    end
  end
  
  def end_caller_session
    session = CallerSession.find(redis_caller_session)
    session.run('end_conf')
  end

end


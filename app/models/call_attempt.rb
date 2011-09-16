class CallAttempt < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  belongs_to :voter
  belongs_to :campaign
  belongs_to :caller
  has_many :call_responses

  scope :for_campaign, lambda { |campaign| {:conditions => ["campaign_id = ?", campaign.id]} }
  scope :for_status, lambda { |status| {:conditions => ["call_attempts.status = ?", status]} }

  def ring_time
    if self.answertime!=nil && self.created_at!=nil
      (self.answertime - self.created_at).to_i
    else
      nil
    end
  end

  def duration
    return nil unless call_start
    ((call_end || Time.now) - self.call_start).to_i
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

  def next_recording(current_recording = nil, call_response = nil)
    return campaign.script.robo_recordings.first.twilio_xml(self) unless current_recording
    if call_response
      (return current_recording.next ? current_recording.next.twilio_xml(self) : current_recording.hangup) if call_response.recording_response
      return current_recording.hangup if call_response.times_attempted > 2
      return current_recording.twilio_xml(self) if call_response && !call_response.recording_response
    end
    current_recording.next ? current_recording.next.twilio_xml(self) : current_recording.hangup
  end

  def connect_to_caller(caller_session = nil)
    caller_session ||= self.campaign.caller_sessions.available.first
    caller_session ? conference(caller_session) : hangup
  end

  def play_recorded_message
    self.voter.update_attributes(:status => CallAttempt::Status::VOICEMAIL)
    self.update_attributes(:status => CallAttempt::Status::VOICEMAIL, :call_end => Time.now)
    Twilio::TwiML::Response.new do |r|
      r.Play self.campaign.recording.file.url
      r.Hangup
    end.text
  end

  def conference(session)
    self.update_attribute(:caller , session.caller)
    Pusher[session.session_key].trigger('voter_start',{:attempt_id => self.id, :voter => self.voter.info })
    self.voter.conference(session)
  end

  def wait(time)
    Twilio::TwiML::Response.new do |r|
      r.Pause :length => time
      r.Redirect "#{connect_call_attempt_path(:id => self.id)}"
    end.text
  end

  def hangup
    Twilio::TwiML::Response.new { |r| r.Hangup }.text
  end

  module Status
    VOICEMAIL = "Message delivered"
    SUCCESS = "Call completed with success."
    INPROGRESS = "Call in progress"
    NOANSWER = "No answer"
    ABANDONED = "Call abandoned"
    BUSY = "No answer busy signal"
    FAILED = "Call failed"
    HANGUP = "Hangup or answering machine"
    READY = "Call ready to dial"
    CANCELLED = "Call cancelled"
    SCHEDULED = 'Scheduled for later'

    MAP = {'in-progress' => INPROGRESS, 'completed' => SUCCESS, 'busy' => BUSY, 'failed' => FAILED, 'no-answer' => NOANSWER, 'canceled' => CANCELLED}
    ALL = MAP.values
    RETRY = [NOANSWER, BUSY, FAILED]
  end

end

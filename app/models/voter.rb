class Voter < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  include CallAttempt::Status

  belongs_to :voter_list
  belongs_to :campaign
  belongs_to :account
  has_many :families
  has_many :call_attempts
  has_many :custom_voter_field_values
  belongs_to :last_call_attempt, :class_name => "CallAttempt"
  belongs_to :caller_session
  has_many :answers
  has_many :note_responses

  validates_presence_of :Phone
  validates_length_of :Phone, :minimum => 10

  scope :existing_phone_in_campaign, lambda { |phone_number, campaign_id| where(:Phone => phone_number).where(:campaign_id => campaign_id) }

  scope :default_order, :order => 'LastName, FirstName, Phone'

  scope :by_status, lambda { |status| where(:status => status) }
  scope :active, where(:active => true)
  scope :yet_to_call, where(:call_back => false).where('status not in (?)', [CallAttempt::Status::INPROGRESS, CallAttempt::Status::RINGING, CallAttempt::Status::READY, CallAttempt::Status::SUCCESS])
  scope :last_call_attempt_before_recycle_rate, lambda { |recycle_rate| where('last_call_attempt_time is null or last_call_attempt_time < ? ', recycle_rate.hours.ago) }
  scope :to_be_dialed, yet_to_call.order(:last_call_attempt_time)
  scope :randomly, order('rand()')
  scope :to_callback, where(:call_back => true)
  scope :scheduled, where(:scheduled_date => (10.minutes.ago..10.minutes.from_now)).where(:status => CallAttempt::Status::SCHEDULED)
  scope :limit, lambda { |n| {:limit => n} }
  scope :without, lambda { |numbers| where('Phone not in (?)', numbers << -1) }
  scope :not_skipped, where('skipped_time is null')
  scope :answered, where('result_date is not null')
  scope :answered_within, lambda { |from, to| where(:result_date => from.beginning_of_day..(to.end_of_day)) }
  scope :last_call_attempt_within, lambda { |from, to| where(:last_call_attempt_time => from..(to + 1.day)) }
  scope :priority_voters, :conditions => {:priority => "1", :status => 'not called'}

  before_validation :sanitize_phone

  cattr_reader :per_page
  @@per_page = 25

  module Status
    NOTCALLED = "not called"
    RETRY = "retry"
  end

  def self.sanitize_phone(phonenumber)
    phonenumber.gsub(/[^0-9]/, "") unless phonenumber.blank?
  end

  def sanitize_phone
    self.Phone = Voter.sanitize_phone(self.Phone)
  end

  def custom_fields
    account.custom_fields.map { |field| CustomVoterFieldValue.voter_fields(self, field).first.try(:value) }
  end

  def selected_fields(selection = nil)
    return [self.Phone] unless selection
    selection.select { |field| Voter.upload_fields.include?(field) }.map { |field| self.send(field) }
  end

  def selected_custom_fields(selection)
    selected_fields = []
    selection.each do |field|
      field = account.custom_voter_fields.find_by_name(field)
      selected_fields << nil and next unless field
      selected_fields << CustomVoterFieldValue.voter_fields(self, field).first.try(:value)
    end
    selected_fields
  end


  def self.upload_fields
    ["Phone", "CustomID", "LastName", "FirstName", "MiddleName", "Suffix", "Email", "address", "city", "state","zip_code", "country"]
  end

  def self.remaining_voters_count_for(column_name, column_value)
    count(:conditions => "#{column_name} = #{column_value} AND active = 1 AND (status not in ('Call in progress','Ringing','Call ready to dial','Call completed with success.') or call_back=1)")
  end

  def dial
    return false if status == Voter::SUCCESS
    message = "#{self.Phone} for campaign id:#{self.campaign_id}"
    logger.info "[dialer] Dialling #{message} "
    call_attempt = new_call_attempt
    callback_params = {:call_attempt_id => call_attempt.id, :host => Settings.host, :port => Settings.port}
    response = Twilio::Call.make(
        self.campaign.caller_id,
        self.Phone,
        twilio_callback_url(callback_params),
        'FallbackUrl' => twilio_report_error_url(callback_params),
        'StatusCallback' => twilio_call_ended_url(callback_params),
        'Timeout' => '20',
        'IfMachine' => 'Hangup'
    )

    if response["TwilioResponse"]["RestException"]
      logger.info "[dialer] Exception when attempted to call #{message}  Response: #{response["TwilioResponse"]["RestException"].inspect}"
      update_attributes(status: CallAttempt::Status::FAILED)
      return false
    end
    logger.info "[dialer] Dialed #{message}. Response: #{response["TwilioResponse"].inspect}"
    call_attempt.update_attributes!(:sid => response["TwilioResponse"]["Call"]["Sid"])
    true
  end

  def dial_predictive
    call_attempt = new_call_attempt(self.campaign.predictive_type)
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    params = {'StatusCallback' => end_call_attempt_url(call_attempt, :host => Settings.host, :port => Settings.port), 'Timeout' => campaign.answering_machine_detect ? "30" : "15"}
    params.merge!({'IfMachine'=> 'Continue'}) if campaign.answering_machine_detect
    response = Twilio::Call.make(campaign.caller_id, self.Phone, connect_call_attempt_url(call_attempt, :host => Settings.host, :port => Settings.port), params)
    if response["TwilioResponse"]["RestException"]
      call_attempt.update_attributes(status: CallAttempt::Status::FAILED, wrapup_time: Time.now)
      update_attributes(status: CallAttempt::Status::FAILED)
      Moderator.publish_event(campaign, 'update_dials_in_progress', {:campaign_id => campaign.id, :dials_in_progress => campaign.call_attempts.not_wrapped_up.length, :voters_remaining => Voter.remaining_voters_count_for('campaign_id', campaign.id)})
      DIALER_LOGGER.info "[dialer] Exception when attempted to call #{self.Phone} for campaign id:#{self.campaign_id}  Response: #{response["TwilioResponse"]["RestException"].inspect}"
      return
    end
    call_attempt.update_attributes(:sid => response["TwilioResponse"]["Call"]["Sid"])
  end

  def conference(session)
    session.update_attributes(:voter_in_progress => self)
  end

  def get_attribute(attribute)
    return self[attribute] if self.has_attribute? attribute
    return unless CustomVoterField.find_by_name(attribute)
    fields = CustomVoterFieldValue.voter_fields(self, CustomVoterField.find_by_name(attribute))
    return if fields.empty?
    return fields.first.value
  end

  def blocked?
    account.blocked_numbers.for_campaign(campaign).map(&:number).include?(self.Phone)
  end

  def capture(response)
    update_attribute(:result_date, Time.now)
    capture_answers(response["question"])
    capture_notes(response['notes'])
  end

  def selected_custom_voter_field_values
    select_custom_fields = campaign.script.try(:selected_custom_fields)
    custom_voter_field_values.try(:select) { |cvf| select_custom_fields.include?(cvf.custom_voter_field.name) } if select_custom_fields.present?
  end

  def info
    {:fields => self.attributes.reject { |k, v| (k == "created_at") ||(k == "updated_at") }, :custom_fields => Hash[*self.selected_custom_voter_field_values.try(:collect) { |cvfv| [cvfv.custom_voter_field.name, cvfv.value] }.try(:flatten)]}.merge!(campaign.script ? campaign.script.selected_fields_json : {})
  end

  def not_yet_called?(call_status)
    status==nil || status==call_status
  end

  def call_attempted_before?(time)
    last_call_attempt_time!=nil && last_call_attempt_time < (Time.now - time)
  end

  def self.to_be_called(campaign_id, active_list_ids, status, recycle_rate=3)
    voters = Voter.find_all_by_campaign_id_and_active(campaign_id, 1, :conditions=>"voter_list_id in (#{active_list_ids.join(",")})", :limit=>300, :order=>"rand()")
    voters.select { |voter| voter.not_yet_called?(status) || (voter.call_attempted_before?(recycle_rate.hours)) }
  end

  def self.just_called_voters_call_back(campaign_id, active_list_ids)
    uncalled = Voter.find_all_by_campaign_id_and_active_and_call_back(campaign_id, 1, 1, :conditions=>"voter_list_id in (#{active_list_ids.join(",")})")
    uncalled.select { |voter| voter.call_attempted_before?(10.minutes) }
  end

  def unanswered_questions
    self.campaign.script.questions.not_answered_by(self)
  end

  def question_not_answered
    unanswered_questions.first
  end

  def skip
    update_attributes(skipped_time: Time.now, status: 'not called')
  end

  def answer(question, response, recorded_by_caller = nil)
    possible_response = question.possible_responses.where(:keypad => response).first
    self.answer_recorded_by = recorded_by_caller
    return unless possible_response
    answer = self.answers.for(question).first.try(:update_attributes, {:possible_response => possible_response}) || answers.create(:question => question, :possible_response => possible_response, campaign: Campaign.find(campaign_id) )
    DIALER_LOGGER.info "??? notifying observer ???"
    notify_observers :answer_recorded
    DIALER_LOGGER.info "... notified observer ..."
    answer
  end

  def answer_recorded_by
    @caller_session
  end

  def current_call_attempt
    answer_recorded_by.attempt_in_progress
  end

  def answer_recorded_by=(caller_session)
    @caller_session = caller_session
  end

  private

  def new_call_attempt(mode = 'robo')
    call_attempt = self.call_attempts.create(:campaign => self.campaign, :dialer_mode => mode, :status => CallAttempt::Status::RINGING)
    self.update_attributes!(:last_call_attempt => call_attempt, :last_call_attempt_time => Time.now, :status => CallAttempt::Status::RINGING)
    Moderator.publish_event(campaign, 'update_dials_in_progress', {:campaign_id => campaign.id, :dials_in_progress => campaign.call_attempts.not_wrapped_up.length, :voters_remaining => Voter.remaining_voters_count_for('campaign_id', campaign.id)})
    call_attempt
  end

  def capture_answers(questions)
    retry_response = nil
    questions.try(:each_pair) do |question_id, answer_id|
      voters_response = PossibleResponse.find(answer_id)
      current_response = answers.find_by_question_id(question_id)
      current_response ? current_response.update_attributes(:possible_response => voters_response, :created_at => Time.now) : answers.create(:possible_response => voters_response, :question => Question.find(question_id), :created_at => Time.now, campaign: Campaign.find(campaign_id))
      retry_response ||= voters_response if voters_response.retry?
    end
    update_attributes(:status => Voter::Status::RETRY) if retry_response
  end

  def capture_notes(notes)
    notes.try(:each_pair) do |note_id, note_res|
      note = Note.find(note_id)
      note_response = note_responses.find_by_note_id(note_id)
      note_response ? note_response.update_attributes(response: note_res) : note_responses.create(response: note_res, note: Note.find(note_id))
    end
  end

end

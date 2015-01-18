require 'fiber'

## 
# Models a Voter record. These records make-up the dial-pool.
#
# Columns:
# - `enabled` is a bitmask. Possible values: :list, :blocked.
# - `active` is not currently in-use.
#
# When the Voter#enabled :list bit is set, the Voter is
# enabled and may be dialed depending on other settings.
# When the Voter#enabled :blocked bit is
# set, the Voter is blocked and cannot be dialed regardless
# of any other settings. 
#
class Voter < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  include CallAttempt::Status
  include ERB::Util

  acts_as_reportable

  UPLOAD_FIELDS = ["phone", "custom_id", "last_name", "first_name", "middle_name", "suffix", "email", "address", "city", "state","zip_code", "country"]

  module Status
    NOTCALLED = 'not called'
    RETRY     = 'retry'
    SKIPPED   = 'skipped'
  end

  belongs_to :account
  belongs_to :campaign
  belongs_to :voter_list, counter_cache: true
  belongs_to :household

  has_many :call_attempts
  has_many :custom_voter_field_values, autosave: true
  belongs_to :last_call_attempt, :class_name => "CallAttempt"
  belongs_to :caller_session
  has_many :answers
  has_many :note_responses

  validates_presence_of :household_id

  bitmask :enabled, as: [:list, :blocked], null: false

  scope :by_campaign, ->(campaign) { where(campaign_id: campaign) }
  # scope :existing_phone_in_campaign, lambda { |phone_number, campaign_id| where(:phone => phone_number).where(:campaign_id => campaign_id) }

  # scope :default_order, :order => 'last_name, first_name, phone'

  # scope :enabled, {:include => :voter_list, :conditions => {'voter_lists.enabled' => true}}
  scope :enabled, with_enabled(:list)
  scope :disabled, without_enabled(:list)

  scope :by_status, lambda { |status| where(:status => status) }
  scope :active, where(:active => true)
  scope :yet_to_call, enabled.where('voters.status not in (?)', [
    CallAttempt::Status::INPROGRESS,
    CallAttempt::Status::RINGING,
    CallAttempt::Status::READY,
    CallAttempt::Status::SUCCESS,
    CallAttempt::Status::FAILED
  ])
  scope :last_call_attempt_before_recycle_rate, lambda {|recycle_rate|
    where('voters.last_call_attempt_time IS NULL OR voters.last_call_attempt_time < ? ', recycle_rate.hours.ago)
  }
  scope :avialable_to_be_retried, lambda {|recycle_rate|
    where('voters.last_call_attempt_time IS NOT NULL AND voters.last_call_attempt_time < ? AND voters.status in (?)',
          recycle_rate.hours.ago, [
            CallAttempt::Status::BUSY,
            CallAttempt::Status::NOANSWER,
            CallAttempt::Status::HANGUP,
            Voter::Status::RETRY
          ])
  }
  scope :not_avialable_to_be_retried, lambda {|recycle_rate|
    where('voters.last_call_attempt_time IS NOT NULL AND voters.last_call_attempt_time >= ? AND voters.status in (?)',
          recycle_rate.hours.ago, [
            CallAttempt::Status::BUSY,
            CallAttempt::Status::NOANSWER,
            CallAttempt::Status::HANGUP,
            Voter::Status::RETRY
          ])
  }

  scope :not_dialed, where('voters.last_call_attempt_time IS NULL').where('voters.status NOT IN (?)', CallAttempt::Status.in_progress_list)
  scope :to_be_dialed, yet_to_call.order(:last_call_attempt_time)
  scope :to_callback, where(:call_back => true)
  # scope :scheduled, enabled.where(:scheduled_date => (10.minutes.ago..10.minutes.from_now)).where(:status => CallAttempt::Status::SCHEDULED)
  scope :scheduled, lambda{raise "Deprecated ImpactDialing Method: Voter.scheduled"}
  scope :limit, lambda { |n| {:limit => n} }
  # scope :without, lambda { |numbers| where('voters.phone not in (?)', numbers + [-1]) }
  scope :not_skipped, where('voters.skipped_time IS NULL')
  scope :answered, where('voters.result_date is not null')
  scope :answered_within, lambda { |from, to| where(:result_date => from.beginning_of_day..(to.end_of_day)) }
  scope :answered_within_timespan, lambda { |from, to| where(:result_date => from..to)}
  scope :last_call_attempt_within, lambda { |from, to| where(:last_call_attempt_time => (from..to)) }
  scope :call_attempts_within, lambda {|from, to| where('call_attempts.created_at' => (from..to)).includes('call_attempts')}
  # scope :priority_voters, enabled.where(:priority => "1", :status => Voter::Status::NOTCALLED)
  scope :priority_voters, lambda{raise "Deprecated ImpactDialing Method: Voter.priority_voters"}
  scope(:not_called_or_retry_or_call_back,
        where(active: true).
        where("status <> ?", CallAttempt::Status::SUCCESS).
        where("status IN (?) OR call_back=1", [
          Status::NOTCALLED,
          Status::RETRY,
          Status::SKIPPED,
          CallAttempt::Status::BUSY,
          CallAttempt::Status::NOANSWER,
          CallAttempt::Status::ABANDONED,
          CallAttempt::Status::HANGUP,
          # CallAttempt::Status::SCHEDULED,
          CallAttempt::Status::CANCELLED
        ])
  )
  scope :remaining_voters_for_campaign, ->(campaign) { from('voters use index (index_voters_on_campaign_id_and_active_and_status_and_call_back)').
    not_called_or_retry_or_call_back.where(campaign_id: campaign) }
  scope :remaining_voters_for_voter_list, ->(voter_list, blocked_numbers=[]) {
    not_called_or_retry_or_call_back.
    not_blocked.
    where(voter_list_id: voter_list)
  }

  # scope :next_in_priority_or_scheduled_queues, lambda {|blocked_numbers|
  #   enabled.without(blocked_numbers).where([
  #     '(priority = ? AND status = ?) '+ # priority_voters
  #     'OR (scheduled_date BETWEEN ? AND ? AND status = ?)', # scheduled
  #     1, Voter::Status::NOTCALLED,
  #     10.minutes.ago, 10.minutes.from_now, CallAttempt::Status::SCHEDULED
  #   ])
  # }
  scope :next_in_priority_or_scheduled_queues, lambda {|blocked_numbers| raise "Deprecated ImpactDialing Method: Voter.next_in_recycled_queue"}

  scope :next_in_recycled_queue, lambda {|recycle_rate, blocked_numbers|
    enabled.not_blocked.
    recycle_rate_expired(recycle_rate).
    where('voters.status NOT IN (?) OR voters.call_back=?', [
      CallAttempt::Status::INPROGRESS, CallAttempt::Status::RINGING,
      CallAttempt::Status::READY, CallAttempt::Status::SUCCESS,
      CallAttempt::Status::FAILED, CallAttempt::Status::VOICEMAIL,
      CallAttempt::Status::HANGUP
    ], 1).
    order('voters.last_call_attempt_time, voters.id')
  }

  # New Shiny
  scope :blocked, with_enabled(:blocked)
  scope :not_blocked, without_enabled(:blocked)
  scope :dialed, where('voters.last_call_attempt_time IS NOT NULL')
  scope :completed, lambda{|campaign|
    where('voters.status' => CallAttempt::Status.completed_list(campaign)).
    where('voters.call_back' => false)
  }
  scope :not_completed, lambda{|campaign| where('voters.status NOT IN (?)', CallAttempt::Status.completed_list(campaign))}
  scope :ringing, where('voters.status = ?', CallAttempt::Status::RINGING)
  scope :failed, where('voters.status = ?', CallAttempt::Status::FAILED)
  scope :available, lambda{|campaign| where('voters.status NOT IN (?)', CallAttempt::Status.not_available_list(campaign))}
  scope :recently_dialed_households, lambda{ |recycle_rate|
    dialed.enabled.active.
    select('DISTINCT(voters.phone), voters.id, voters.last_call_attempt_time').
    where('voters.last_call_attempt_time > ?', recycle_rate.hours.ago)
  }
  scope :available_for_retry, lambda {|campaign|
    enabled.active.
    where('voters.status IN (?) OR voters.call_back=?',
          CallAttempt::Status.retry_list(campaign),
          true).
    recycle_rate_expired(campaign.recycle_rate)
  }
  scope :not_available_for_retry, lambda {|campaign|
    where('(voters.status IN (?)) OR (voters.last_call_attempt_time IS NOT NULL AND voters.last_call_attempt_time >= ?)',
      CallAttempt::Status.not_available_list(campaign),
      campaign.recycle_rate.hours.ago
    )
  }
  scope :recycle_rate_expired, lambda {|recycle_rate|
    where('voters.last_call_attempt_time IS NULL OR '+
          'voters.last_call_attempt_time < ?',
          recycle_rate.hours.ago)
  }
  scope :not_ringing, lambda{ where('voters.status <> ?', CallAttempt::Status::RINGING) }
  scope :with_manual_message_drop, not_ringing.joins(:last_call_attempt).where('call_attempts.recording_id IS NOT NULL').where(call_attempts: {recording_delivered_manually: true})
  scope :with_auto_message_drop, not_ringing.joins(:last_call_attempt).where('call_attempts.recording_id IS NOT NULL').where(call_attempts: {recording_delivered_manually: false})

  # voters index: campaign_id_active_enabled_status_call_back
  # blocked numbers index: account_id_campaign_id_number
  scope :generally_available, lambda{|campaign|
    enabled.not_blocked.
    where('status NOT IN (?) OR (status = ? AND call_back = ?)',
      CallAttempt::Status.not_available_list(campaign), 
      CallAttempt::Status::SUCCESS,
      true
    )
  }
  scope :not_available_list, lambda{|campaign|
    not_available_for_retry(campaign) #.
    # not_completed(campaign) #.
    # joins('JOIN voters as recently_dialed on
    #        voters.phone = recently_dialed.phone
    #        and voters.campaign_id = recently_dialed.campaign_id
    #        and recently_dialed.last_call_attempt_time is not null
    #        and TIMESTAMPDIFF(MINUTE, recently_dialed.last_call_attempt_time, UTC_TIMESTAMP()) < ' +
    #        campaign.recycle_rate.minutes.to_s)
  }
  scope :available_list, lambda{ |campaign|
    generally_available(campaign).
    recycle_rate_expired(campaign.recycle_rate).

    # joins('LEFT OUTER JOIN voters AS recently_dialed ON
    #        voters.phone = recently_dialed.phone AND
    #        voters.campaign_id = recently_dialed.campaign_id AND
    #        recently_dialed.last_call_attempt_time IS NOT NULL AND
    #        TIMESTAMPDIFF(MINUTE, recently_dialed.last_call_attempt_time, UTC_TIMESTAMP()) < '+campaign.recycle_rate.minutes.to_s).
    # where('recently_dialed.last_call_attempt_time IS NULL').

    order('voters.last_call_attempt_time, voters.id')
  }

  scope :skipped, where('voters.status = ?', Status::SKIPPED)
  scope :busy, where('voters.status = ?', CallAttempt::Status::BUSY)
  #/New Shiny

  # Newest
  scope :not_presentable, lambda{|campaign|
    where(call_back: false).where(status: CallAttempt::Status.completed_list(campaign))
  }
  scope :presentable, lambda{|campaign|
    where('call_back = ? OR status IN (?)', true, CallAttempt::Status.available_list(campaign))
  }
  #/Newest

  cattr_reader :per_page
  @@per_page = 25

private
  def autolink(text)
    domain_regex = /[\w]+[\w\.\-]?(\.[a-z]){1,2}/i
    email_regex  = /[\w\-\.]+[\w\-\+\.]?@/i
    proto_regex  = /\bhttp(s)?:\/\//i
    space_regex  = /\s+/

    if text =~ domain_regex and text !~ space_regex
      # it looks like a domain, is it an email?
      if text =~ email_regex
        return "<a target=\"_blank\" href=\"mailto:#{html_escape(text)}\">#{html_escape(text)}</a>"
      else
        proto = text =~ proto_regex ? '' : 'http://'
        return "<a target=\"_blank\" href=\"#{proto}#{html_escape(text)}\">#{html_escape(text)}</a>"
      end
    end

    html_escape(text)
  end

public
  # make activerecord-import work with bitmask_attributes
  def enabled=(raw_value)
    if raw_value.is_a?(Fixnum) && raw_value <= Voter.bitmasks[:enabled].values.sum
      self.send(:write_attribute, :enabled, raw_value)
    else
      values = raw_value.kind_of?(Array) ? raw_value : [raw_value]
      self.enabled.replace(values.reject{|value| value.blank?})
    end
  end
  ##
  # Select the next voter.
  #
  # Voters that have not been dialed at all have highest precedence.
  # The precedence order is:
  #
  # - not dialed
  # - not skipped
  # - retry
  #
  # In all cases, if current_voter_id is provided then best effort is made
  # to return a voter with an id > current_voter_id, respecting the above
  # precedence order.
  #
  # A voter has not been dialed when the last_call_attempt_time is null and
  # the status is `Status::NOTCALLED`.
  #
  # A voter has not been skipped when the campaign is in Preview mode and
  # no caller has clicked the Skip button when viewing that voter's info.
  #
  # A voter is a retry if it has been dialed but the call was not connected for
  # whatever reason OR the call was connected but the caller selected a response that
  # is configured to set the call_back flag to true.
  #
  def self.next_voter(voters, recycle_rate, blocked_numbers, current_voter_id)
    not_dialed_queue = voters.enabled.not_blocked.not_dialed
    retry_queue      = voters.next_in_recycled_queue(recycle_rate, blocked_numbers)
    _not_skipped     = not_dialed_queue.not_skipped.first
    _not_skipped     ||= retry_queue.not_skipped.first

    if _not_skipped.nil?
      if current_voter_id.present?
        voter = not_dialed_queue.where(["voters.id > ?", current_voter_id]).first
      end
      voter ||= not_dialed_queue.first

      if current_voter_id.present?
        voter ||= retry_queue.where(["voters.id > ?", current_voter_id]).first
      end
      voter ||= retry_queue.first
    else
      if current_voter_id.present?
        voter = not_dialed_queue.where(["voters.id > ?", current_voter_id]).not_skipped.first
      end
      voter ||= not_dialed_queue.not_skipped.first

      if current_voter_id.present?
        voter ||= retry_queue.where(["voters.id > ?", current_voter_id]).not_skipped.first
      end
      voter ||= _not_skipped
    end

    return voter
  end

  scope :live, enabled.not_blocked

  def blocked?
    enabled?(:blocked)
  end

  def skipped?
    status == Status::SKIPPED
  end

  def available_for_dial?
    last_call_attempt_time.to_f < campaign.recycle_rate.hours.ago.to_f &&
    CallAttempt::Status.available_list(campaign).include?(status)
  end

  def can_eventually_be_retried?
    CallAttempt::Status.retry_list(campaign).include?(status) ||
    (call_back && CallAttempt::Status::SUCCESS)
  end

  def abandoned
    self.status = CallAttempt::Status::ABANDONED
    self.call_back = false
    self.caller_session = nil
    self.caller_id = nil
  end

  def update_voicemail_history
    parts = (self.voicemail_history || '').split(',')
    parts << campaign.recording_id
    self.voicemail_history = parts.join(',')
  end

  def update_voicemail_history!
    update_voicemail_history
    save
  end

  def update_call_back_after_message_drop
    self.call_back = campaign.call_back_after_voicemail_delivery?
  end

  def yet_to_receive_voicemail?
    voicemail_history.blank?
  end

  def do_not_call_back?
    (not not_called?) and (not call_back?) and (not retry?)
  end

  def not_called?
    status == Voter::Status::NOTCALLED
  end

  def retry?
    status == Voter::Status::RETRY
  end

  def dispositioned(call_attempt)
    dial_queue             = CallFlow::DialQueue.new(campaign)
    self.status            = call_attempt.status
    self.caller_id         = call_attempt.caller_id
    self.caller_session_id = nil
    if do_not_call_back?
      dial_queue.remove(self)
    end
  end

  def self.upload_fields
    ["phone", "custom_id", "last_name", "first_name", "middle_name", "suffix", "email", "address", "city", "state","zip_code", "country"]
  end

  def get_attribute(attribute)
    return self[attribute] if self.has_attribute? attribute
    return unless CustomVoterField.find_by_name(attribute)
    fields = CustomVoterFieldValue.voter_fields(self, CustomVoterField.find_by_name(attribute))
    return if fields.empty?
    return fields.first.value
  end

  def selected_custom_voter_field_values
    select_custom_fields = campaign.script.try(:selected_custom_fields)
    custom_voter_field_values.try(:select) { |cvf| select_custom_fields.include?(cvf.custom_voter_field.name) } if select_custom_fields.present?
  end

  def info
    fields = {}
    f      = self.attributes.reject{|k,v| k =~ /(created|updated)_at/}

    custom_fields = Hash[ *self.selected_custom_voter_field_values.try(:collect) { |cvfv| [cvfv.custom_voter_field.name, autolink(cvfv.value)] }.try(:flatten) ]

    f.each{|k,v| fields[k] = autolink(v)}

    {
      fields: fields,
      custom_fields: custom_fields
    }.merge!(campaign.script.selected_fields_json)
  end

  def cache_data
    system_fields = UPLOAD_FIELDS + ['id']
    data = {
      id: self.id,
      fields: {},
      custom_fields: {}
    }
    self.attributes.each do |field, value|
      next unless system_fields.include?(field)

      data[:fields][field] = autolink(value)
    end

    custom_voter_field_values.each do |custom_value|
      data[:custom_fields][custom_value.custom_voter_field.name] = autolink(custom_value.value)
    end

    data
  end

  def unanswered_questions
    campaign.script.questions.not_answered_by(self)
  end

  def question_not_answered
    unanswered_questions.first
  end

  def update_call_back(possible_responses)
    if possible_responses.any?(&:retry?)
      self.call_back = true
      self.status    = Voter::Status::RETRY
    else
      self.call_back = false
    end
  end

  def update_call_back_incrementally(possible_response, first_increment = false)
    if possible_response.retry?
      self.call_back = true
      self.status    = Voter::Status::RETRY
    else
      if updated_at.to_i <= 15.minutes.ago.to_i or first_increment
        self.call_back = false
      end
    end
  end

  # this is called from AnsweredJob and should run only
  # after #dispositioned has run (which is called from PersistCalls)
  # otherwise, the status of the voter will be overwritten.
  def persist_answers(questions, call_attempt)
    return if questions.nil?

    question_answers   = JSON.parse(questions)
    possible_responses = []
    question_answers.try(:each_pair) do |question_id, answer_id|
      voters_response = PossibleResponse.find(answer_id)
      answers.create({
        possible_response: voters_response,
        question: Question.find(question_id),
        created_at: call_attempt.created_at,
        campaign: Campaign.find(campaign_id),
        caller: call_attempt.caller,
        call_attempt_id: call_attempt.id
      })
      possible_responses << voters_response
    end
    
    update_call_back(possible_responses)
    save
  end

  def persist_notes(notes_json, call_attempt)
    return if notes_json.nil?
    notes = JSON.parse(notes_json)
    notes.try(:each_pair) do |note_id, note_res|
      note = Note.find(note_id)
      note_responses.create(response: note_res, note: Note.find(note_id), call_attempt_id: call_attempt.id, campaign_id: campaign_id)
    end
  end
end

# ## Schema Information
#
# Table name: `voters`
#
# ### Columns
#
# Name                          | Type               | Attributes
# ----------------------------- | ------------------ | ---------------------------
# **`id`**                      | `integer`          | `not null, primary key`
# **`phone`**                   | `string(255)`      |
# **`custom_id`**               | `string(255)`      |
# **`last_name`**               | `string(255)`      |
# **`first_name`**              | `string(255)`      |
# **`middle_name`**             | `string(255)`      |
# **`suffix`**                  | `string(255)`      |
# **`email`**                   | `string(255)`      |
# **`result`**                  | `string(255)`      |
# **`caller_session_id`**       | `integer`          |
# **`campaign_id`**             | `integer`          |
# **`account_id`**              | `integer`          |
# **`active`**                  | `boolean`          | `default(TRUE)`
# **`created_at`**              | `datetime`         |
# **`updated_at`**              | `datetime`         |
# **`status`**                  | `string(255)`      | `default("not called")`
# **`voter_list_id`**           | `integer`          |
# **`call_back`**               | `boolean`          | `default(FALSE)`
# **`caller_id`**               | `integer`          |
# **`result_digit`**            | `string(255)`      |
# **`attempt_id`**              | `integer`          |
# **`result_date`**             | `datetime`         |
# **`last_call_attempt_id`**    | `integer`          |
# **`last_call_attempt_time`**  | `datetime`         |
# **`num_family`**              | `integer`          | `default(1)`
# **`family_id_answered`**      | `integer`          |
# **`result_json`**             | `text`             |
# **`scheduled_date`**          | `datetime`         |
# **`address`**                 | `string(255)`      |
# **`city`**                    | `string(255)`      |
# **`state`**                   | `string(255)`      |
# **`zip_code`**                | `string(255)`      |
# **`country`**                 | `string(255)`      |
# **`skipped_time`**            | `datetime`         |
# **`priority`**                | `string(255)`      |
# **`lock_version`**            | `integer`          | `default(0)`
# **`enabled`**                 | `integer`          | `default(0), not null`
# **`voicemail_history`**       | `string(255)`      |
# **`household_id`**            | `integer`          |
#
# ### Indexes
#
# * `index_priority_voters`:
#     * **`campaign_id`**
#     * **`enabled`**
#     * **`priority`**
#     * **`status`**
# * `index_voters_caller_id_campaign_id`:
#     * **`caller_id`**
#     * **`campaign_id`**
# * `index_voters_customid_campaign_id`:
#     * **`custom_id`**
#     * **`campaign_id`**
# * `index_voters_on_Phone_and_voter_list_id`:
#     * **`phone`**
#     * **`voter_list_id`**
# * `index_voters_on_attempt_id`:
#     * **`attempt_id`**
# * `index_voters_on_caller_session_id`:
#     * **`caller_session_id`**
# * `index_voters_on_campaign_id_and_active_and_status_and_call_back`:
#     * **`campaign_id`**
#     * **`active`**
#     * **`status`**
#     * **`call_back`**
# * `index_voters_on_campaign_id_and_status_and_id`:
#     * **`campaign_id`**
#     * **`status`**
#     * **`id`**
# * `index_voters_on_household_id`:
#     * **`household_id`**
# * `index_voters_on_status`:
#     * **`status`**
# * `index_voters_on_voter_list_id`:
#     * **`voter_list_id`**
# * `report_query`:
#     * **`campaign_id`**
#     * **`id`**
# * `voters_campaign_status_time`:
#     * **`campaign_id`**
#     * **`status`**
#     * **`last_call_attempt_time`**
# * `voters_enabled_campaign_time_status`:
#     * **`enabled`**
#     * **`campaign_id`**
#     * **`last_call_attempt_time`**
#     * **`status`**
#

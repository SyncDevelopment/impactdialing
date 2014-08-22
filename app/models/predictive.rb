class Predictive < Campaign
  include SidekiqEvents


  def dial_resque
    set_calculate_dialing
    Resque.enqueue(CalculateDialsJob, self.id)
  end

  def set_calculate_dialing
    Resque.redis.set("dial_calculate:#{self.id}", true)
    Resque.redis.expire("dial_calculate:#{self.id}", 8)
  end

  def calculate_dialing?
    Resque.redis.exists("dial_calculate:#{self.id}")
  end


  def increment_campaign_dial_count(counter)
    Resque.redis.incrby("dial_count:#{self.id}", counter)
  end


  def decrement_campaign_dial_count(decrement_counter)
    Resque.redis.decrby("dial_count:#{self.id}", decrement_counter)
  end

  def self.dial_campaign?(campaign_id)
    Resque.redis.exists("dial_campaign:#{campaign_id}")
  end

  def dialing_count
    call_attempts.with_status(CallAttempt::Status::READY).between(10.seconds.ago, Time.now).size
  end

  def number_of_voters_to_dial
    num_to_call = 0
    dials_made = call_attempts.between(10.minutes.ago, Time.now).size
    if dials_made == 0 || !abandon_rate_acceptable?
      num_to_call = caller_sessions.available.size - call_attempts.with_status(CallAttempt::Status::RINGING).between(15.seconds.ago, Time.now).size
    else
      num_to_call = number_of_simulated_voters_to_dial
    end
    num_to_call
  end

  def choose_voters_to_dial(num_voters)
    return [] if num_voters < 1

    limit_voters = num_voters <= 0 ? 0 : num_voters
    blocked      = account.blocked_numbers.for_campaign(self).pluck(:number)
    voter_query  = all_voters.active.enabled.without(blocked).limit(limit_voters)
    not_dialed   = voter_query.not_dialed.where(:call_back => false).pluck(:id)

    if not_dialed.size > 0
      voters = not_dialed
    else
      voters = voter_query.last_call_attempt_before_recycle_rate(recycle_rate).
                to_be_dialed.pluck(:id)
    end

    set_voter_status_to_read_for_dial!(voters)
    check_campaign_out_of_numbers(voters)
    check_campaign_fit_to_dial
    voters
  end

  def check_campaign_fit_to_dial
    if !account.funds_available?
      caller_sessions.available.each do |cs|
        Providers::Phone::Call.redirect_for(cs, :account_has_no_funds)
      end
      return
    end

    if time_period_exceeded?
      caller_sessions.available.each do |cs|
        Providers::Phone::Call.redirect_for(cs, :time_period_exceeded)
      end
      return
    end
  end

  def set_voter_status_to_read_for_dial!(voters)
    Voter.where(id: voters).update_all(status: CallAttempt::Status::READY)
  end

  def check_campaign_out_of_numbers(voters)
    if voters.blank?
      caller_sessions.available.pluck(:id).each { |id| enqueue_call_flow(CampaignOutOfNumbersJob, [id]) }
    end
  end


  def abandon_rate_acceptable?
    answered_dials = call_attempts.between(Time.at(1334561385) , Time.now).with_status([CallAttempt::Status::SUCCESS, CallAttempt::Status::SCHEDULED]).size
    abandon_count = call_attempts.between(Time.at(1334561385) , Time.now).with_status(CallAttempt::Status::ABANDONED).size
    abandon_rate = abandon_count.to_f/(answered_dials <= 0 ? 1 : answered_dials)
    abandon_rate <= acceptable_abandon_rate
  end

  def number_of_simulated_voters_to_dial
    available_callers = caller_sessions.available.size
    dials_to_make = (best_dials_simulated * available_callers) - call_attempts.with_status(CallAttempt::Status::RINGING).between(15.seconds.ago, Time.now).size
    dials_to_make.to_i
  end

  def self.do_not_call_in_production?(campaign_id)
    !Resque.redis.exists("do_not_call:#{campaign_id}")
  end


  def best_dials_simulated
    simulated_values.nil? ? 1 : simulated_values.best_dials.nil? ? 1 : simulated_values.best_dials.ceil > TwilioLimit.get ? TwilioLimit.get : simulated_values.best_dials.ceil
  end

  def best_conversation_simulated
    simulated_values.nil? ? 1000 : (simulated_values.best_conversation.nil? || simulated_values.best_conversation == 0) ? 1000 : simulated_values.best_conversation
  end

  def longest_conversation_simulated
    simulated_values.nil? ? 1000 : simulated_values.longest_conversation.nil? ? 0 : simulated_values.longest_conversation
  end

  def best_wrapup_simulated
    simulated_values.nil? ? 1000 : (simulated_values.best_wrapup_time.nil? || simulated_values.best_wrapup_time == 0) ? 1000 : simulated_values.best_wrapup_time
  end

  def caller_conference_started_event(current_voter_id)
    {event: 'caller_connected_dialer',data: {}}
  end

  def voter_connected_event(call)
    {event: 'voter_connected_dialer', data: {call_id:  call.id, voter:  call.voter.info}}
  end

  def call_answered_machine_event(call_attempt)
    Hash.new
  end



end

# ## Schema Information
#
# Table name: `campaigns`
#
# ### Columns
#
# Name                                      | Type               | Attributes
# ----------------------------------------- | ------------------ | ---------------------------
# **`id`**                                  | `integer`          | `not null, primary key`
# **`campaign_id`**                         | `string(255)`      |
# **`name`**                                | `string(255)`      |
# **`account_id`**                          | `integer`          |
# **`script_id`**                           | `integer`          |
# **`active`**                              | `boolean`          | `default(TRUE)`
# **`created_at`**                          | `datetime`         |
# **`updated_at`**                          | `datetime`         |
# **`caller_id`**                           | `string(255)`      |
# **`type`**                                | `string(255)`      |
# **`recording_id`**                        | `integer`          |
# **`use_recordings`**                      | `boolean`          | `default(FALSE)`
# **`calls_in_progress`**                   | `boolean`          | `default(FALSE)`
# **`recycle_rate`**                        | `integer`          | `default(1)`
# **`answering_machine_detect`**            | `boolean`          |
# **`start_time`**                          | `time`             |
# **`end_time`**                            | `time`             |
# **`time_zone`**                           | `string(255)`      |
# **`acceptable_abandon_rate`**             | `float`            |
# **`call_back_after_voicemail_delivery`**  | `boolean`          | `default(FALSE)`
# **`caller_can_drop_message_manually`**    | `boolean`          | `default(FALSE)`
#

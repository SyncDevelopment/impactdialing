module PreviewPowerCampaign
  def next_voter_in_dial_queue(current_voter_id = nil)
    bench_start = Time.now.to_f
    namespace   = [self.type.downcase]

    if CallFlow::DialQueue.enabled?
      voter = redis_next_voter_in_dial_queue
      namespace << 'redis'
    else
      voter = mysql_next_voter_in_dial_queue(current_voter_id)
      namespace << 'mysql'
    end
    namespace << "ac-#{self.account_id}"
    namespace << "ca-#{self.id}"

    bench_end = Time.now.to_f

    ImpactPlatform::Metrics.measure('dialer.voter_load', (bench_end - bench_start), namespace.join('.'))

    return voter
  end

  def redis_next_voter_in_dial_queue
    begin
      dial_queue  = CallFlow::DialQueue.new(self)
      # try to re-seed before loading next voter to allow
      # looping through a single voter (use case: skipping voters in preview)
      dial_queue.seed
      voter_attrs = dial_queue.next(1).first
      
      return nil if voter_attrs.nil?

      voter = Voter.find voter_attrs['id']
      voter.update_attributes!(status: CallAttempt::Status::READY)
      dial_queue.reload_if_below_threshold

    rescue ActiveRecord::StaleObjectError => e
      Rails.logger.error "RecycleRate next_voter_in_dial_queue #{self.try(:type) || 'Campaign'}[#{self.try(:id)}] CurrentVoter[#{current_voter_id}] StaleObjectError - retrying..."
      retry
    end
    return voter
  end

  def mysql_next_voter_in_dial_queue(current_voter_id=nil)
    # blocked_numbers = account.blocked_numbers.for_campaign(self).pluck(:number)
    blocked_numbers = []
    begin
      voter = Voter.next_voter(all_voters, recycle_rate, blocked_numbers, current_voter_id)

      update_voter_status_to_ready(voter)
    rescue ActiveRecord::StaleObjectError => e
      Rails.logger.error "RecycleRate next_voter_in_dial_queue #{self.try(:type) || 'Campaign'}[#{self.try(:id)}] CurrentVoter[#{current_voter_id}] StaleObjectError - retrying..."
      retry
    end
    return voter
  end

  def next_in_dial_queue
    next_voter_in_dial_queue
  end

  def update_voter_status_to_ready(voter)
    voter.update_attributes(status: CallAttempt::Status::READY) unless voter.nil?
  end

  def caller_conference_started_event(current_voter_id)
    next_voter = next_voter_in_dial_queue(current_voter_id)
    info = next_voter.nil? ? {campaign_out_of_leads: true} : next_voter.info
    {event: 'conference_started', data: info}
  end

  def voter_connected_event(call)
    {event: 'voter_connected', data: {call_id:  call.id}}
  end

  def call_answered_machine_event(call_attempt)
    Rails.logger.info "Deprecated ImpactDialing Method: PreviewPowerCampaign#call_answered_machine_event"
    next_voter = next_voter_in_dial_queue(call_attempt.voter.id)
    {event: 'dial_next_voter', data: next_voter.nil? ? {} : next_voter.info}
  end
end

module PreviewPowerCampaign
  def next_voter_in_dial_queue(current_voter_id = nil)
    do_not_call_numbers = account.blocked_numbers.for_campaign(self).pluck(:number)
    begin
      voter = all_voters.next_in_priority_or_scheduled_queues(do_not_call_numbers).first
      voter ||= Voter.next_voter(all_voters, recycle_rate, do_not_call_numbers, current_voter_id)

      Rails.logger.error "RecycleRate next_voter_in_dial_queue #{self.try(:type) || 'Campaign'}[#{self.try(:id)}] CurrentVoter[#{current_voter_id}] NextVoter[#{voter.try(:id)}]"

      update_voter_status_to_ready(voter)
    rescue ActiveRecord::StaleObjectError => e
      Rails.logger.error "RecycleRate next_voter_in_dial_queue #{self.try(:type) || 'Campaign'}[#{self.try(:id)}] CurrentVoter[#{current_voter_id}] StaleObjectError - retrying..."
      retry
    end
    Rails.logger.error "RecycleRate next_voter_in_dial_queue #{self.try(:type) || 'Campaign'}[#{self.try(:id)}] CurrentVoter[#{current_voter_id}] Returning[#{voter.try(:id)}:#{voter.try(:status)}]"
    return voter
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
    raise "Deprecated: PreviewPowerCampaign#call_answered_machine_event"
    next_voter = next_voter_in_dial_queue(call_attempt.voter.id)
    {event: 'dial_next_voter', data: next_voter.nil? ? {} : next_voter.info}
  end
end

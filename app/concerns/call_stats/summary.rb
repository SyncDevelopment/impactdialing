class CallStats::Summary
  attr_reader :campaign

  delegate :all_voters, to: :campaign
  delegate :households, to: :campaign

  def initialize(campaign)
    @campaign = campaign
  end

  def per_status_counts
    @per_status_counts ||= households.select('status').group("status").count(:id)
  end

  def dialed_and_complete_count
    @dialed_and_complete_count ||= all_voters.completed(campaign).count
  end

  def dialed_count
    @dialed_count ||= (households.dialed.count + ringing_count)
  end

  def ringing_count
    Twillio::InflightStats.new(campaign).get('ringing')
  end

  def failed_count
    @failed_count ||= households.failed.count
  end

  def households_not_dialed_count
    @not_dialed_count ||= (households.not_dialed.count - ringing_count)
  end

  def voters_not_reached
    @voters_not_reached ||= all_voters.where(status: Voter::Status::NOTCALLED).count
  end

  def dialed_and_available_for_retry_count
    @dialed_and_available_for_retry_count ||= households.dialed.available(campaign).count
  end

  def dialed_and_not_available_for_retry_count
    @dialed_and_not_available_for_retry_count ||= households.dialed.not_available(campaign).count
  end
end

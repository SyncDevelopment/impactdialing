require 'librato_resque'
require 'impact_platform'

module CallFlow::DialQueue::Jobs
  class Recycle
    @queue = :upload_download
    extend ImpactPlatform::Heroku::UploadDownloadHooks
    extend LibratoResque

    def self.perform
      # 2 weeks is a long time but there are currently no restrictions on Campaign#recycle_rate
      # if the campaign is created via API or the form is hacked then recycle rate could be > 72 hours
      # 2014 (w/ mid-term election) saw total of 1103 different campaigns though so 
      # loading caller sessions from the last 2 weeks won't return many distinct campaigns
      CallerSession.where('created_at > ?', 2.weeks.ago).select('DISTINCT caller_sessions.campaign_id').includes(:campaign).find_in_batches do |caller_sessions|
        caller_sessions.each do |caller_session|
          campaign   = caller_session.campaign
          dial_queue = CallFlow::DialQueue.new(campaign)
          stale      = dial_queue.available.presented_and_stale

          stale.each do |scored_phone|
            score     = scored_phone.last
            phone     = scored_phone.first
            household = campaign.households.find_by_phone(phone)
            
            household.update_attributes({
              presented_at: score
            })
            dial_queue.dialed(household)
          end

          dial_queue.recycle!
        end
      end
    end
  end
end
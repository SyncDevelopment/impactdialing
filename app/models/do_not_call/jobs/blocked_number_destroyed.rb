require 'librato_resque'

##
# Update all +Household+ records with `blocked: false` for a given account or campaign with a phone number matching the
# +BlockedNumber#number+ of the given `blocked_number_id`.
# This job is queued from after create in +BlockedNumber+.
#
# ### Metrics
#
# - failed
# - sql timing
#
# ### Monitoring
#
# Alert conditions:
#
# - 1 failure
#
class DoNotCall::Jobs::BlockedNumberDestroyed
  extend LibratoResque
  
  @queue = :dial_queue

  def self.perform(account_id, campaign_id, phone_number)
    households = households_with(account_id, campaign_id, phone_number)

    return if households.count.zero?

    households.with_blocked(:cell).update_all(blocked: Household.bitmask_for_blocked(:cell))
    households.without_blocked(:cell).update_all(blocked: 0)

    campaign   = Campaign.find campaign_id
    dial_queue = CallFlow::DialQueue.new(campaign)
    households.each do |household|
      household.voters.each do |voter|
        dial_queue.cache(voter) if voter.enabled?(:list)
      end
    end

    Rails.logger.info "DoNotCall::Jobs::BlockedNumberDestroyed Account[#{account_id}] Campaign[#{campaign_id}] Number[#{phone_number}] marked #{households.count} households unblocked."
  end

  def self.households_with(account_id, campaign_id, phone_number)
    account    = Account.find(account_id)
    households = if campaign_id.present?
                   account.campaigns.find(campaign_id).households
                 else
                   account.households
                 end

    households.where(phone: phone_number).includes(:voters)
  end
end

class BlockedNumber < ActiveRecord::Base
  belongs_to :account
  belongs_to :campaign

  before_validation :sanitize_phone
  validates_presence_of :number
  validates_length_of :number, :minimum => 10, :maximum => 16
  validates_numericality_of :number
  validates_presence_of :account
  validates_uniqueness_of :number, scope: [:account_id, :campaign_id]
  
  scope :for_campaign, lambda {|campaign| where("campaign_id is NULL OR campaign_id = ?", campaign.id)}
  scope :matching, lambda{|campaign, phone| for_campaign(campaign).where(number: phone)}

  after_create :scrub_voters

private
  def sanitize_phone
    return if number.blank?

    self.number = number.gsub(/[\(\)\+ -]/, "")
  end

  def scrub_voters
    Resque.enqueue BlockedNumberScrubber, self.id
  end
end

# ## Schema Information
#
# Table name: `blocked_numbers`
#
# ### Columns
#
# Name               | Type               | Attributes
# ------------------ | ------------------ | ---------------------------
# **`id`**           | `integer`          | `not null, primary key`
# **`number`**       | `string(255)`      |
# **`account_id`**   | `integer`          |
# **`created_at`**   | `datetime`         |
# **`updated_at`**   | `datetime`         |
# **`campaign_id`**  | `integer`          |
#
# ### Indexes
#
# * `index_blocked_numbers_account_id_campaign_id`:
#     * **`account_id`**
#     * **`campaign_id`**
# * `index_on_blocked_numbers_number`:
#     * **`number`**
#

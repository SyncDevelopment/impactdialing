class Household < ActiveRecord::Base
  attr_accessible :account_id, :campaign_id, :enabled, :last_call_attempt_id, :phone, :presented_to_caller, :status, :voicemail_history, :voter_list_id

  belongs_to :account
  belongs_to :campaign
  belongs_to :voter_list #, counter_cache: true
  belongs_to :last_call_attempt, class_name: 'CallAttempt'
  has_many :call_attempts

  bitmask :enabled, as: [:list, :blocked], null: false

  before_validation :sanitize_phone
  validates_presence_of :phone
  validates_length_of :phone, minimum: 10, maximum: 16
  validates_uniqueness_of :phone, scope: :campaign_id

private
  def sanitize_phone
    self.phone = PhoneNumber.sanitize(phone)
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
end

# ## Schema Information
#
# Table name: `households`
#
# ### Columns
#
# Name                        | Type               | Attributes
# --------------------------- | ------------------ | ---------------------------
# **`id`**                    | `integer`          | `not null, primary key`
# **`account_id`**            | `integer`          | `not null`
# **`campaign_id`**           | `integer`          | `not null`
# **`voter_list_id`**         | `integer`          | `not null`
# **`last_call_attempt_id`**  | `integer`          |
# **`phone`**                 | `string(255)`      | `not null`
# **`enabled`**               | `integer`          | `default(0), not null`
# **`voicemail_history`**     | `string(255)`      |
# **`status`**                | `string(255)`      | `default("not called"), not null`
# **`presented_at`**          | `datetime`         | `not null`
# **`created_at`**            | `datetime`         | `not null`
# **`updated_at`**            | `datetime`         | `not null`
#

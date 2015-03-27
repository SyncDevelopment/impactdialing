require 'spec_helper'

describe CallerGroup, :type => :model do
  context 'validations' do
    it {is_expected.to validate_presence_of :name}
    it {is_expected.to have_many :callers}
    it {is_expected.to belong_to :campaign}
    it {is_expected.to belong_to :account}
  end

  it 'updates its callers to its campaign when saved' do
    original_campaign = create(:preview)
    caller = create(:caller, campaign_id: original_campaign.id)
    caller_group = create(:caller_group, campaign_id: original_campaign.id, callers: [caller])
    new_campaign = create(:predictive, name: "new")
    expect(Resque).to receive(:enqueue).with(CallerGroupJob, caller_group.id)
    caller_group.update_attributes(campaign_id: new_campaign.id)
    expect(caller_group.campaign).to eq(new_campaign)

    # caller.campaign.should eq new_campaign
  end
end

# ## Schema Information
#
# Table name: `caller_groups`
#
# ### Columns
#
# Name               | Type               | Attributes
# ------------------ | ------------------ | ---------------------------
# **`id`**           | `integer`          | `not null, primary key`
# **`name`**         | `string(255)`      | `not null`
# **`campaign_id`**  | `integer`          | `not null`
# **`created_at`**   | `datetime`         | `not null`
# **`updated_at`**   | `datetime`         | `not null`
# **`account_id`**   | `integer`          | `not null`
#

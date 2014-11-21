require 'spec_helper'

describe 'DoNotCall::Jobs::UnblockVoter' do
  let(:account){ create(:account) }
  let(:campaign){ create(:power, account: account) }
  let(:voters){ create_list(:realistic_voter, 10, :blocked, account: account, campaign: campaign) }
  let(:voter_blocked_account_wide){ voters.first }
  let(:voter_blocked_campaign_wide){ voters.last }
  let(:account_wide){ create(:blocked_number, account: account, number: voter_blocked_account_wide.phone) }
  let(:campaign_wide){ create(:blocked_number, account: account, campaign: campaign, number: voter_blocked_campaign_wide.phone) }

  let(:other_account){ create(:account) }
  let(:other_campaign){ create(:power, account: account) }
  let(:other_voters){ create_list(:realistic_voter, 10, :blocked, account: other_account, campaign: other_campaign) }
  let(:other_account_wide){ create(:blocked_number, account: other_account, number: other_voters.first.phone) }
  let(:other_campaign_wide){ create(:blocked_number, account: other_account, campaign: other_campaign, number: other_voters.last.phone) }

  before do
    other_voters.second.update_attributes!(phone: voters.first.phone)
    other_voters.third.update_attributes!(phone: voters.last.phone)

    DoNotCall::Jobs::UnblockVoter.perform(account.id, campaign.id, account_wide.number)
    DoNotCall::Jobs::UnblockVoter.perform(account.id, campaign.id, campaign_wide.number)
    DoNotCall::Jobs::UnblockVoter.perform(account.id, campaign.id, other_account_wide.number)
    DoNotCall::Jobs::UnblockVoter.perform(account.id, campaign.id, other_campaign_wide.number)
  end
  
  it 'marks voter unblocked from account-wide list' do
    expect( voter_blocked_account_wide.reload.blocked? ).to be_falsey
  end

  it 'marks voter unblocked from campaign-wide list' do
    expect( voter_blocked_campaign_wide.reload.blocked? ).to be_falsey
  end

  it 'does not mark voter from another account' do
    expect( other_voters.second.reload.blocked? ).to be_truthy
  end

  it 'does not mark voter from another campaign' do
    expect( other_voters.third.reload.blocked? ).to be_truthy
  end
end
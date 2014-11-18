require 'spec_helper'

shared_examples 'Preview/Power#next_voter_in_dial_queue' do
  it 're-populates queue via background job' do
    dial_queue.clear(:available)
    dial_queue.reload_if_below_threshold(:available)
    expected = {'class' => 'CallFlow::Jobs::CacheAvailableVoters', 'args' => [campaign.id]}
    expect(Resque.peek(:dialer_worker)).to eq expected
  end

  it "returns uncalled voter before called voter" do
    campaign = create(:power)
    create(:voter, status: CallAttempt::Status::SUCCESS, :last_call_attempt_time => 2.hours.ago, campaign: campaign)
    uncalled_voter = create(:voter, status: Voter::Status::NOTCALLED, campaign: campaign)
    cache_available_voters(campaign)

    expect(campaign.next_voter_in_dial_queue(nil)).to eq(uncalled_voter)
  end

  it "returns voter with respect to a current voter" do
    campaign       = create(:power)
    uncalled_voter = create(:voter, status: Voter::Status::NOTCALLED, campaign: campaign)
    current_voter  = create(:voter, status: Voter::Status::NOTCALLED, campaign: campaign)
    next_voter     = create(:voter, status: Voter::Status::NOTCALLED, campaign: campaign)
    dial_queue     = cache_available_voters(campaign)
    dial_queue.next(2) # pop the uncalled & current voter off the list, this test is a bit silly
                       # todo: fix or remove this test
    expect(campaign.next_voter_in_dial_queue(current_voter.id)).to eq(next_voter)
  end

  it "returns no number if only voter to be called a retry and last called time is within campaign recycle rate" do
    campaign        = create(:power, recycle_rate: 2)
    retry_voter     = create(:realistic_voter, :call_back, :recently_dialed, campaign: campaign)
    current_voter   = create(:realistic_voter, :success, :recently_dialed, campaign: campaign)
    actual          = campaign.next_voter_in_dial_queue(current_voter.id)

    expect(actual).to be_nil
  end

  it 'does not return any voter who is blocked by DNC' do
    account        = create(:account)
    campaign       = create(:power, {account: account})
    voter          = create(:realistic_voter, :blocked, campaign: campaign)
    priority_voter = create(:realistic_voter, :blocked, campaign: campaign)
    create(:blocked_number, account: account, campaign: campaign, number: voter.phone)
    create(:blocked_number, account: account, campaign: campaign, number: priority_voter.phone)

    expect(campaign.next_voter_in_dial_queue(nil)).to be_nil
  end
end
require "spec_helper"


describe Preview do

  describe "next voter to be dialed" do

    it "returns priority  not called voter first" do
      campaign = create(:preview)
      voter = create(:voter, :status => 'not called', :campaign => campaign)
      priority_voter = create(:voter, :status => 'not called', :campaign => campaign, priority: "1")
      caller_session = create(:caller_session)
      campaign.next_voter_in_dial_queue(nil).should == priority_voter
    end

    it "returns uncalled voter before called voter" do
      campaign = create(:preview)
      caller_session = create(:caller_session)
      create(:voter, :status => CallAttempt::Status::SUCCESS, :last_call_attempt_time => 2.hours.ago, :campaign => campaign)
      uncalled_voter = create(:voter, :status => Voter::Status::NOTCALLED, :campaign => campaign)
      campaign.next_voter_in_dial_queue(nil).should == uncalled_voter
    end

    it "returns any scheduled voter within a ten minute window before an uncalled voter" do
      campaign = create(:preview)
      caller_session = create(:caller_session)
      scheduled_voter = create(:voter, :status => CallAttempt::Status::SCHEDULED, :last_call_attempt_time => 2.hours.ago, :scheduled_date => 1.minute.from_now, :campaign => campaign)
      create(:voter, :status => Voter::Status::NOTCALLED, :campaign => campaign)
      campaign.next_voter_in_dial_queue(nil).should == scheduled_voter
    end

    it "returns next voter in list if scheduled voter is more than 10 minutes away from call" do
      campaign = create(:preview)
      caller_session = create(:caller_session)
      scheduled_voter = create(:voter, :status => CallAttempt::Status::SCHEDULED, :last_call_attempt_time => 2.hours.ago, :scheduled_date => 20.minute.from_now, :campaign => campaign)
      current_voter = create(:voter, :status => Voter::Status::NOTCALLED, :campaign => campaign)
      next_voter = create(:voter, :status => Voter::Status::NOTCALLED, :campaign => campaign)
      campaign.next_voter_in_dial_queue(current_voter.id).should == next_voter
    end


    it "returns voter with respect to a current voter" do
      campaign = create(:preview)
      caller_session = create(:caller_session)
      uncalled_voter = create(:voter, :status => Voter::Status::NOTCALLED, :campaign => campaign)
      current_voter = create(:voter, :status => Voter::Status::NOTCALLED, :campaign => campaign)
      next_voter = create(:voter, :status => Voter::Status::NOTCALLED, :campaign => campaign)
      campaign.next_voter_in_dial_queue(current_voter.id).should == next_voter
    end

    it "returns no number if only voter to be called a retry and last called time is within campaign recycle rate" do
      time_now = Time.now.utc
      Time.stub(:now).and_return(time_now)
      campaign = create(:preview, recycle_rate: 2)
      scheduled_voter = create(:voter, :first_name => 'scheduled voter', :status => CallAttempt::Status::SCHEDULED, :last_call_attempt_time => 2.hours.ago, :scheduled_date => 20.minutes.from_now, :campaign => campaign)
      retry_voter = create(:voter, :status => CallAttempt::Status::VOICEMAIL, last_call_attempt_time: 1.hours.ago, :campaign => campaign)
      current_voter = create(:voter, :status => CallAttempt::Status::SUCCESS, :campaign => campaign)
      campaign.next_voter_in_dial_queue(current_voter.id).should be_nil
    end

    it 'does not return any voter w/ a phone number in the blocked number list' do
      blocked = ['1234567890', '0987654321']
      campaign = create(:preview)
      campaign.stub(:blocked_numbers){ blocked }
      voter = create(:voter, :status => 'not called', :campaign => campaign, phone: blocked.first)
      priority_voter = create(:voter, :status => 'not called', :campaign => campaign, priority: "1", phone: blocked.second)
      caller_session = create(:caller_session)
      campaign.next_voter_in_dial_queue(nil).should be_nil
    end

  end

end

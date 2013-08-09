require "spec_helper"

describe Predictive do

  describe "choose voter" do

    it "should properly choose the next voters to dial" do
      account = create(:account, :activated => true)
      campaign = create(:predictive, :account => account, :caller_id => "0123456789")
      voter_list = create(:voter_list, :campaign => campaign, :active => true)
      voter = create(:voter, :campaign => campaign, :status=>"not called", :voter_list => voter_list, :account => account)
      campaign.choose_voters_to_dial(1).should == [voter.id]
    end

    xit "should properly choose limit of voters to dial" do
      account = create(:account, :activated => true)
      campaign = create(:predictive, :account => account, :caller_id => "0123456789")
      voter_list = create(:voter_list, :campaign => campaign, :active => true)
      priority_voter = create(:voter, :campaign => campaign, :status=>"not called", :voter_list => voter_list, :account => account, priority: "1")
      scheduled_voter = create(:voter, :status => CallAttempt::Status::SCHEDULED, :last_call_attempt_time => 2.hours.ago, :scheduled_date => 1.minute.from_now, :campaign => campaign)
      voter = create(:voter, :campaign => campaign, :status=>"not called", :voter_list => voter_list, :account => account)
      campaign.choose_voters_to_dial(1).should == [priority_voter.id]
    end

    xit "should properly choose limit of voters to dial for scheduled and priority" do
      account = create(:account, :activated => true)
      campaign = create(:predictive, :account => account, :caller_id => "0123456789")
      voter_list = create(:voter_list, :campaign => campaign, :active => true)
      priority_voter = create(:voter, :campaign => campaign, :status=>"not called", :voter_list => voter_list, :account => account, priority: "1")
      scheduled_voter = create(:voter, :status => CallAttempt::Status::SCHEDULED, :last_call_attempt_time => 2.hours.ago, :scheduled_date => 1.minute.from_now, :campaign => campaign)
      voter = create(:voter, :campaign => campaign, :status=>"not called", :voter_list => voter_list, :account => account)
      campaign.choose_voters_to_dial(2).should == [priority_voter.id,scheduled_voter.id]
    end

    xit "should properly choose limit of voters to dial for scheduled and priority and voters to dial" do
      account = create(:account, :activated => true)
      campaign = create(:predictive, :account => account, :caller_id => "0123456789")
      voter_list = create(:voter_list, :campaign => campaign, :active => true)
      priority_voter = create(:voter, :campaign => campaign, :status=>"not called", :voter_list => voter_list, :account => account, priority: "1")
      scheduled_voter = create(:voter, :status => CallAttempt::Status::SCHEDULED, :last_call_attempt_time => 2.hours.ago, :scheduled_date => 1.minute.from_now, :campaign => campaign)
      voter = create(:voter, :campaign => campaign, :status=>"not called", :voter_list => voter_list, :account => account)
      voter1 = create(:voter, :campaign => campaign, :status=>"not called", :voter_list => voter_list, :account => account)
      campaign.choose_voters_to_dial(3).should == [priority_voter.id,scheduled_voter.id,voter.id]
    end

    it "dials voters off enabled lists only" do
       campaign = create(:predictive)
       enabled_list = create(:voter_list, :campaign => campaign, :active => true, :enabled => true)
       disabled_list = create(:voter_list, :campaign => campaign, :active => true, :enabled => false)
       voter1 = create(:voter, :campaign => campaign, :voter_list => enabled_list, enabled: true)
       voter2 = create(:voter, :campaign => campaign, :voter_list => disabled_list, enabled: false)
       campaign.choose_voters_to_dial(2).should == [voter1.id]
    end

     xit "should  choose priority voter as the next voters to dial" do
       account = create(:account, :activated => true)
       campaign = create(:predictive, :account => account, :caller_id => "0123456789")
       voter_list = create(:voter_list, :campaign => campaign, :active => true)
       voter = create(:voter, :campaign => campaign, :status=>"not called", :voter_list => voter_list, :account => account)
       priority_voter = create(:voter, :campaign => campaign, :status=>"not called", :voter_list => voter_list, :account => account, priority: "1")
       campaign.choose_voters_to_dial(1).should == [priority_voter.id]
     end

     it "excludes system blocked numbers" do
       account = create(:account, :activated => true)
       campaign = create(:predictive, :account => account)
       voter_list = create(:voter_list, :campaign => campaign, :active => true)
       unblocked_voter = create(:voter, :campaign => campaign, :status => 'not called', :voter_list => voter_list, :account => account)
       blocked_voter = create(:voter, :campaign => campaign, :status => 'not called', :voter_list => voter_list, :account => account)
       create(:blocked_number, :number => blocked_voter.phone, :account => account, :campaign=>nil)
       campaign.choose_voters_to_dial(10).should == [unblocked_voter.id]
     end

     it "excludes campaign blocked numbers" do
       account = create(:account, :activated => true)
       campaign = create(:predictive, :account => account)
       voter_list = create(:voter_list, :campaign => campaign, :active => true)
       unblocked_voter = create(:voter, :campaign => campaign, :status => 'not called', :voter_list => voter_list, :account => account)
       blocked_voter = create(:voter, :campaign => campaign, :status => 'not called', :voter_list => voter_list, :account => account)
       create(:blocked_number, :number => blocked_voter.phone, :account => account, :campaign=>campaign)
       create(:blocked_number, :number => unblocked_voter.phone, :account => account, :campaign=>create(:campaign))
       campaign.choose_voters_to_dial(10).should == [unblocked_voter.id]
     end

     it "does not redial a voter that is in progress" do
       account = create(:account, :activated => true)
       campaign = create(:predictive, :account => account)
       voter = create(:voter, :campaign => campaign, :status => CallAttempt::Status::SUCCESS)
       create(:call_attempt, :voter => voter, :status => CallAttempt::Status::SUCCESS)
       campaign.choose_voters_to_dial(20).should_not include(voter.id)
     end

     it "does not dial voter who has been just dialed recycle rate" do
      account = create(:account, :activated => true)
      campaign = create(:predictive, :account => account, recycle_rate: 3)
      voter = create(:voter, :campaign => campaign, :status => CallAttempt::Status::BUSY, last_call_attempt_time: Time.now - 1.hour)
      create(:call_attempt, :voter => voter, :status => CallAttempt::Status::BUSY)
      campaign.choose_voters_to_dial(20).should_not include(voter.id)
     end

     it "dials voter who has been dialed passed recycle rate" do
      account = create(:account, :activated => true)
      campaign = create(:predictive, :account => account, recycle_rate: 3)
      voter = create(:voter, :campaign => campaign, :status => CallAttempt::Status::BUSY, last_call_attempt_time: Time.now - 4.hours)
      create(:call_attempt, :voter => voter, :status => CallAttempt::Status::BUSY)
      campaign.choose_voters_to_dial(20).should include(voter.id)
     end

     it "should redirect caller to campaign has no voters if numbers run out" do
       account = create(:account, :activated => true)
       campaign = create(:predictive, :account => account, recycle_rate: 3)
       caller_session = create(:webui_caller_session, caller: create(:caller), on_call: true, available_for_call: true, campaign: campaign, state: "connected", voter_in_progress: nil)
       voter = create(:voter, :campaign => campaign, :status => CallAttempt::Status::BUSY, last_call_attempt_time: Time.now - 2.hours)
       create(:call_attempt, :voter => voter, :status => CallAttempt::Status::BUSY)
       campaign.stub(:check_campaign_fit_to_dial)
       campaign.should_receive(:enqueue_call_flow).with(CampaignOutOfNumbersJob, [caller_session.id])
       campaign.choose_voters_to_dial(20).should eq([])
     end

  end

  describe "best dials simulated" do

    it "should return 1 as best dials if simulated_values is nil" do
      campaign = create(:predictive)
      campaign.best_dials_simulated.should eq(1)
    end

    it "should return 1 as best dials if  best_dials simulated_values is nil" do
      campaign = create(:predictive)
      campaign.best_dials_simulated.should eq(1)
    end

    it "should return best dials  if  best_dials simulated_values is has a value" do
      simulated_values = SimulatedValues.create(best_dials: 1.8, best_conversation: 0, longest_conversation: 0)
      campaign = create(:predictive, :simulated_values => simulated_values)
      campaign.best_dials_simulated.should eq(2)
    end

   it "should return best dials  as 5 if  best_dials simulated_values is greater than 3" do
      simulated_values = SimulatedValues.create(best_dials: 10.0, best_conversation: 0, longest_conversation: 0)
      campaign = create(:predictive, :simulated_values => simulated_values)
      campaign.best_dials_simulated.should eq(4)
    end


  end

  describe "best conversations simulated" do

    it "should return 0 as best conversation if simulated_values is nil" do
      campaign = create(:predictive)
      campaign.best_conversation_simulated.should eq(1000)
    end

    it "should return 0 as best conversation if best_conversation simulated_values is nil" do
      campaign = create(:predictive)
      campaign.best_conversation_simulated.should eq(1000)
    end

    it "should return best conversation if  best_conversation simulated_values is has a value" do
      simulated_values = SimulatedValues.create(best_dials: 1.8, best_conversation: 34.34, longest_conversation: 0)
      campaign = create(:predictive, :simulated_values => simulated_values)
      campaign.best_conversation_simulated.should eq(34.34)
    end


  end

  describe "longest conversations simulated" do

    it "should return 0 as longest conversation if simulated_values is nil" do
      campaign = create(:predictive)
      campaign.longest_conversation_simulated.should eq(1000)
    end

    it "should return 0 as longest conversation if longest_conversation simulated_values is nil" do
      campaign = create(:predictive)
      campaign.longest_conversation_simulated.should eq(1000)
    end

    it "should return longest conversation if  longest_conversation simulated_values is has a value" do
      simulated_values = SimulatedValues.create(best_dials: 1.8, best_conversation: 34.34, longest_conversation: 67.09)
      campaign = create(:predictive, :simulated_values => simulated_values)
      campaign.longest_conversation_simulated.should eq(67.09)
    end

  end

  describe "number of voters to dial" do

    it "should dial one line per caller  if no calls have been made in the last ten minutes" do
      simulated_values = SimulatedValues.create(best_dials: 2.33345, best_conversation: 34.0076, longest_conversation: 42.0876, best_wrapup_time: 10.076)
      campaign = create(:predictive, simulated_values: simulated_values)
      2.times do |index|
        caller_session = create(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => true)
      end
      num_to_call = campaign.number_of_voters_to_dial
      campaign.should_not_receive(:num_to_call_predictive_simulate)
      caller_sessions = CallerSession.find_all_by_campaign_id(campaign.id)
      num_to_call.should eq(caller_sessions.size)
    end

    it "should dial one line per caller if abandonment rate exceeds acceptable rate" do
      simulated_values = SimulatedValues.create(best_dials: 2.33345, best_conversation: 34.0076, longest_conversation: 42.0876, best_wrapup_time: 10.076)
      campaign = create(:predictive, simulated_values: simulated_values, :acceptable_abandon_rate => 0.02)
      create(:call_attempt, :campaign => campaign, :call_start => 20.seconds.ago)
      create(:call_attempt, :campaign => campaign, :call_start => 20.seconds.ago, :status => CallAttempt::Status::ABANDONED)
      2.times { create(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => true) }
      num_to_call = campaign.number_of_voters_to_dial
      campaign.should_not_receive(:num_to_call_predictive_simulate)
      caller_sessions = CallerSession.find_all_by_campaign_id(campaign.id)
      num_to_call.should eq(caller_sessions.size)
    end

    it "should dial one line per caller minus Ringin lines if abandonment rate exceeds acceptable rate" do
      simulated_values = SimulatedValues.create(best_dials: 2.33345, best_conversation: 34.0076, longest_conversation: 42.0876, best_wrapup_time: 10.076)
      campaign = create(:predictive, simulated_values: simulated_values, :acceptable_abandon_rate => 0.02)
      create(:call_attempt, :campaign => campaign, :call_start => 20.seconds.ago)
      create(:call_attempt, :campaign => campaign, :call_start => 20.seconds.ago, :status => CallAttempt::Status::ABANDONED)
      2.times { create(:call_attempt, :campaign => campaign, :created_at => 10.seconds.ago, status: CallAttempt::Status::RINGING ) }
      3.times { create(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => true) }
      num_to_call = campaign.number_of_voters_to_dial
      campaign.should_not_receive(:num_to_call_predictive_simulate)
      caller_sessions = CallerSession.find_all_by_campaign_id(campaign.id)
      num_to_call.should eq(1)
    end

  end

  describe "abandon rate acceptable" do
    it "should return false if  not acceptable" do
      campaign = create(:predictive, acceptable_abandon_rate: 0.03)
      10.times { create(:call_attempt, :campaign => campaign, :call_start => 40.seconds.ago, call_end: 10.seconds.ago, :wrapup_time => 5.seconds.ago, :status => CallAttempt::Status::SUCCESS) }
      10.times { create(:call_attempt, :campaign => campaign, :call_start => 40.seconds.ago, call_end: 10.seconds.ago, :wrapup_time => 5.seconds.ago, :status => CallAttempt::Status::ABANDONED) }
      campaign.abandon_rate_acceptable?.should be_false
    end
    it "should return true if  acceptable" do
      campaign = create(:predictive, acceptable_abandon_rate: 0.03)
      40.times { create(:call_attempt, :campaign => campaign, :call_start => 40.seconds.ago, call_end: 10.seconds.ago, :wrapup_time => 5.seconds.ago, :status => CallAttempt::Status::SUCCESS) }
      1.times { create(:call_attempt, :campaign => campaign, :call_start => 40.seconds.ago, call_end: 10.seconds.ago, :wrapup_time => 5.seconds.ago, :status => CallAttempt::Status::ABANDONED) }
      campaign.abandon_rate_acceptable?.should be_true
    end

    it "should only consider answered calls for abandonment rate" do
      campaign = create(:predictive, acceptable_abandon_rate: 0.01)
      9.times { create(:call_attempt, :campaign => campaign, :call_start => 40.seconds.ago, call_end: 10.seconds.ago, :wrapup_time => 5.seconds.ago, :status => CallAttempt::Status::SUCCESS) }
      2.times { create(:call_attempt, :campaign => campaign, :call_start => 40.seconds.ago, call_end: 10.seconds.ago, :wrapup_time => 5.seconds.ago, :status => CallAttempt::Status::BUSY) }
      1.times { create(:call_attempt, :campaign => campaign, :call_start => 40.seconds.ago, call_end: 10.seconds.ago, :wrapup_time => 5.seconds.ago, :status => CallAttempt::Status::ABANDONED) }
      campaign.abandon_rate_acceptable?.should be_false
    end
  end

  describe "number_of_simulated_voters_to_dial" do


   xit "should determine calls to make give the simulated best_dials when call_attempts prior int the last 10 mins are present" do
     simulated_values = SimulatedValues.create(best_dials: 2.33345, best_conversation: 34.0076, longest_conversation: 42.0876, best_wrapup_time: 10.076)
     campaign = create(:predictive, :simulated_values => simulated_values)

     10.times { create(:caller_session, :campaign => campaign, :on_call => true, :available_for_call => true) }
     10.times { create(:call_attempt, :campaign => campaign, :call_start => 40.seconds.ago, call_end: 10.seconds.ago, :wrapup_time => 5.seconds.ago, :status => CallAttempt::Status::SUCCESS) }
     10.times { create(:call_attempt, :campaign => campaign, :call_start => 40.seconds.ago, call_end: 8.seconds.ago, :status => CallAttempt::Status::SUCCESS) }
     3.times { create(:call_attempt, :campaign => campaign, :call_start => 80.seconds.ago, call_end: 38.seconds.ago, :status => CallAttempt::Status::SUCCESS) }
     create(:call_attempt, :campaign => campaign, :call_start => 35.seconds.ago,call_end: 10.seconds.ago, :status => CallAttempt::Status::SUCCESS)
     create(:call_attempt, :campaign => campaign, :call_start => 65.seconds.ago, call_end: 10.seconds.ago, :status => CallAttempt::Status::SUCCESS)
     2.times { create(:call_attempt, :campaign => campaign, :call_start => 10.seconds.ago, :status => CallAttempt::Status::RINGING) }
     unavailable_caller_sessions = CallerSession.all[1..7]
     unavailable_caller_sessions.each { |caller_session| caller_session.update_attribute(:available_for_call, false) }
     5.times { create(:call_attempt, :campaign => campaign, :call_start => 5.seconds.ago, :status => CallAttempt::Status::INPROGRESS) }
     2.times { create(:call_attempt, :campaign => campaign, :call_start => 20.seconds.ago, :status => CallAttempt::Status::INPROGRESS) }
     campaign.number_of_simulated_voters_to_dial.should eq(18)
   end

   it "should determine calls to make give the simulated best_dials when call_attempts prior int the last 10 mins are present" do
       simulated_values = SimulatedValues.create(best_dials: 1, best_conversation: 0, longest_conversation: 0)
       campaign = create(:predictive, :simulated_values => simulated_values)
       3.times do |index|
         caller_session = create(:caller_session, :campaign => campaign, :on_call => true, :available_for_call => true)
       end

       campaign.number_of_simulated_voters_to_dial.should eq(3)
   end

   it "should determine calls to make when no simulated values" do
     campaign = create(:predictive)
     3.times do |index|
       caller_session = create(:caller_session, :campaign => campaign, :on_call => true, :available_for_call => true)
     end
     campaign.number_of_simulated_voters_to_dial.should eq(3)
   end

  end

end

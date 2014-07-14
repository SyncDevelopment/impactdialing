require "spec_helper"

describe Campaign do

  describe "voter" do

   it "should return zero voters, if active_voter_list_ids is empty" do
     campaign = create(:campaign, :account => create(:account, :activated => true), type: Campaign::Type::PREVIEW)
     VoterList.should_receive(:active_voter_list_ids).with(campaign.id).and_return([])
     campaign.voters("not called").should == []
   end

   it "should return voters to be call" do
     campaign = create(:campaign, :account => create(:account, :activated => true), recycle_rate: 3,type: Campaign::Type::PREVIEW)
     VoterList.should_receive(:active_voter_list_ids).with(campaign.id).and_return([12, 123])
     Voter.should_receive(:to_be_called).with(campaign.id, [12, 123], "not called", 3).and_return(["v1", "v2", "v3", "v2"])
     Voter.should_not_receive(:just_called_voters_call_back).with(campaign.id, [12, 123])
     campaign.voters("not called").length.should == 3
   end

  end

  describe 'callbacks' do
    let(:campaign){ create(:campaign) }

    describe 'sanitizing message service settings' do
      before do
        campaign.call_back_after_voicemail_delivery = true
        campaign.answering_machine_detect           = true
        campaign.use_recordings                     = true
        campaign.save
        campaign.use_recordings.should be_truthy
        campaign.answering_machine_detect.should be_truthy
        campaign.call_back_after_voicemail_delivery.should be_truthy
      end
      it 'should set use_recordings & call_back_after_voicemail_delivery to false, if it is true and answering_machine_detect is false' do
        campaign.answering_machine_detect = false
        campaign.save
        campaign.use_recordings.should be_falsey
        campaign.answering_machine_detect.should be_falsey
        campaign.call_back_after_voicemail_delivery.should be_falsey
      end

      it 'should set call_back_after_voicemail_delivery to false, if it is true and use_recordings and caller_can_drop_message_manually are both false' do
        campaign.use_recordings = false
        campaign.save
        campaign.call_back_after_voicemail_delivery.should be_falsey
        campaign.answering_machine_detect.should be_truthy
        campaign.use_recordings.should be_falsey
      end

      it 'should not abort callback chain' do
        campaign.use_recordings = false
        campaign.caller_can_drop_message_manually = true
        campaign.save
        campaign.caller_can_drop_message_manually.should be_truthy
      end
    end
  end

  describe "validations" do
    let(:campaign) { create(:campaign, :account => create(:account)) }
    it {campaign.should validate_presence_of :name}
    it {campaign.should validate_presence_of :script}
    it {campaign.should validate_presence_of :type}
    it {
      # this breaks w/ NameError for some reason
      # campaign.should ensure_inclusion_of(:type).in_array(['Preview', 'Power', 'Predictive'])
      # => NameError: wrong constant name shouldamatchersteststring
      # => seems to do w/ the special :type attr but odd that it passed previously
      # => because this also breaks w/ NameError but different message
      # campaign.type = 'Blah'
      # campaign.should have(1).error_on(:type)
      # => NameError: uninitialized constant Blah
      # looks like an edge-case in shoulda
      campaign.type = 'Account'
      campaign.should have(1).error_on(:type)
      campaign.type = 'Campaign'
      campaign.should have(1).error_on(:type)
      campaign.type = 'Preview'
      campaign.should have(0).errors_on(:type)
      campaign.type = 'Power'
      campaign.should have(0).errors_on(:type)
      campaign.type = 'Predictive'
      campaign.should have(0).errors_on(:type)

    }
    it {campaign.should validate_presence_of :recycle_rate}
    it {campaign.should validate_numericality_of :recycle_rate}
    it {campaign.should validate_presence_of :time_zone}
    it {campaign.should ensure_inclusion_of(:time_zone).in_array(ActiveSupport::TimeZone.zones_map.map {|z| z.first})}
    it {campaign.should validate_presence_of :start_time}
    it {campaign.should validate_presence_of :end_time}
    it {campaign.should validate_numericality_of :acceptable_abandon_rate}
    it {campaign.should have_many :caller_groups}

    it 'return validation error, if caller id is either blank, not a number or not a valid length' do
      campaign = build(:campaign, account: create(:account))
      campaign.save(:validate => false)
      campaign.update_attributes(:caller_id => '23456yuiid').should be_falsey
      campaign.errors[:base].should == ['Caller ID must be a 10-digit North American phone number or begin with "+" and the country code']
      campaign.update_attributes(:called_id => '').should be_falsey
      campaign.errors[:base].should == ['Caller ID must be a 10-digit North American phone number or begin with "+" and the country code']
    end

    it "skips validations for an international phone number" do
      campaign = build(:campaign, :caller_id => "+98743987")
      campaign.should be_valid
      campaign = build(:campaign, :caller_id => "+987AB87A")
      campaign.should be_valid
    end

    it 'return validation error, when callers are login and try to change dialing mode' do
      campaign = create(:preview)
      campaign.caller_sessions.create!(on_call: true, state: "initial")
      campaign.type = Campaign::Type::POWER
      campaign.save.should be_falsey
      campaign.errors[:base].should == ['You cannot change dialing modes while callers are logged in.']
      campaign.reload
      campaign.type.should eq(Campaign::Type::PREVIEW)
    end

    it 'can change dialing mode when not on call' do
      campaign = create(:preview)
      campaign.type = Campaign::Type::POWER
      campaign.save.should be_truthy
      campaign.type.should eq(Campaign::Type::POWER)
    end


    it "should not invoke Twilio if caller id is not present" do
      TwilioLib.should_not_receive(:new)
      campaign = create(:campaign, :type =>Campaign::Type::PREVIEW)
      campaign.caller_id = nil
      campaign.save
    end

    it "sets use_recordings to false when answering_machine_detect is false" do
      campaign = create(:power, {answering_machine_detect: false})
      campaign.use_recordings = true
      campaign.save
      campaign.use_recordings.should be_falsey
    end

    it "sets call_back_after_voicemail_delivery to false when both use_recordings and caller_can_drop_message_manually are false" do
      campaign = create(:power, {use_recordings: false, caller_can_drop_message_manually: false})
      campaign.call_back_after_voicemail_delivery = true
      campaign.save
      campaign.call_back_after_voicemail_delivery.should be_falsey
    end

    describe "delete campaign" do

      it "should not delete a campaign that has active callers assigned to it" do
        caller = create(:caller)
        campaign = create(:preview, callers: [caller])
        campaign.active = false
        campaign.save.should be_falsey
        campaign.errors[:base].should == ['There are currently callers assigned to this campaign. Please assign them to another campaign before deleting this one.']
      end

      it "should  delete a campaign that has no active callers assigned to it" do
        caller = create(:caller)
        campaign = create(:preview)
        campaign.active = false
        campaign.save.should be_truthy
      end

      it "should delete a campaign that has inactive callers assigned to it and change their campaign to nil" do
        campaign = create(:campaign)
        caller = create(:caller, campaign: campaign, active: false)
        campaign.active = false
        campaign.save.should be_truthy
      end
    end

  end


  describe "campaigns with caller sessions that are on call" do
    let(:user) { create(:user) }
    let(:campaign) { create(:preview, :account => user.account) }

    it "should give the campaign only once even if it has multiple caller sessions" do
      create(:caller_session, :campaign => campaign, :on_call => true)
      create(:caller_session, :campaign => campaign, :on_call => true)
      user.account.campaigns.with_running_caller_sessions.should == [campaign]
    end

    it "should not give campaigns without on_call caller sessions" do
      create(:caller_session, :campaign => campaign, :on_call => false)
      user.account.campaigns.with_running_caller_sessions.should be_empty
    end

    it "should not give another user's campaign'" do
      create(:caller_session, :campaign => create(:campaign, :account => create(:account)), :on_call => true)
      user.account.campaigns.with_running_caller_sessions.should be_empty
    end

  end

  describe "answer report" do
      let(:script) { create(:script)}
      let(:campaign) { create(:predictive, :script => script) }
      let(:call_attempt1) { create(:call_attempt,:campaign => campaign) }
      let(:call_attempt2) { create(:call_attempt,:campaign => campaign) }
      let(:call_attempt3) { create(:call_attempt,:campaign => campaign) }
      let(:call_attempt4) { create(:call_attempt,:campaign => campaign) }

      let(:voter1) { create(:voter, :campaign => campaign, :last_call_attempt => call_attempt1)}
      let(:voter2) { create(:voter, :campaign => campaign, :last_call_attempt => call_attempt2)}
      let(:voter3) { create(:voter, :campaign => campaign, :last_call_attempt => call_attempt3)}
      let(:voter4) { create(:voter, :campaign => campaign, :last_call_attempt => call_attempt4)}

    it "should give the final results of a campaign as a Hash" do
      now = Time.now
      campaign2 = create(:predictive)
      question1 = create(:question, :text => "hw are u", :script => script)
      question2 = create(:question, :text => "wr r u", :script => script)
      possible_response1 = create(:possible_response, :value => "fine", :question => question1)
      possible_response2 = create(:possible_response, :value => "super", :question => question1)
      create(:answer, :voter => create(:voter, :campaign => campaign), campaign: campaign, :possible_response => possible_response1, :question => question1, :created_at => now)
      create(:answer, :voter => create(:voter, :campaign => campaign), campaign: campaign,:possible_response => possible_response2, :question => question1, :created_at => now)
      create(:answer, :voter => create(:voter, :campaign => campaign), campaign: campaign,:possible_response => question1.possible_responses.first, :question => question1, :created_at => now)
      create(:answer, :voter => create(:voter, :campaign => campaign), campaign: campaign, :possible_response => possible_response2, :question => question2, :created_at => now)
      campaign.answers_result(now, now).should == {script.id => {script: script.name, questions: {"hw are u" => [{:answer=>"[No response]", :number=>1, :percentage=>33}, {answer: possible_response1.value, number: 1, percentage: 33}, {answer: possible_response2.value, number: 2, percentage: 66}], "wr r u" => [{answer: "[No response]", number: 0, percentage: 0}]}}}
    end

    it "should give the final results of a campaign as a Hash" do
      now = Time.now
      new_script = create(:script, name: 'new script')
      campaign2 = create(:predictive)
      question1 = create(:question, :text => "hw are u", :script => script)
      question2 = create(:question, :text => "whos your daddy", :script => new_script)
      possible_response1 = create(:possible_response, :value => "fine", :question => question1)
      possible_response2 = create(:possible_response, :value => "super", :question => question1)
      possible_response3 = create(:possible_response, :value => "john", :question => question2)
      possible_response4 = create(:possible_response, :value => "dou", :question => question2)
      create(:answer, :voter => create(:voter, :campaign => campaign), campaign: campaign, :possible_response => possible_response1, :question => question1, :created_at => now)
      create(:answer, :voter => create(:voter, :campaign => campaign), campaign: campaign,:possible_response => possible_response2, :question => question1, :created_at => now)
      create(:answer, :voter => create(:voter, :campaign => campaign), campaign: campaign,:possible_response => possible_response3, :question => question2, :created_at => now)
      create(:answer, :voter => create(:voter, :campaign => campaign), campaign: campaign, :possible_response => possible_response4, :question => question2, :created_at => now)
      campaign.answers_result(now, now).should == {
        script.id => {
          script: script.name,
          questions: {
            "hw are u" => [
              {:answer=>"[No response]", :number=>0, :percentage=>0},
              {answer: possible_response1.value, number: 1, percentage: 50},
              {answer: possible_response2.value, number: 1, percentage: 50}

            ]
          }
        },
        new_script.id => {
          script: new_script.name,
          questions: {
            "whos your daddy" => [
              {:answer=>"[No response]", :number=>0, :percentage=>0},
              {answer: possible_response3.value, number: 1, percentage: 50},
              {answer: possible_response4.value, number: 1, percentage: 50}

            ]
          }
        }
      }
    end

  end

  describe "amd" do
    describe "contine on amd" do
      it "should return true if answering machine detect and recording present" do
        campaign = create(:preview, answering_machine_detect: true, use_recordings: true)
        campaign.continue_on_amd.should be_truthy
      end

      it "should return false if answering machine detect and recording not present" do
        campaign = create(:preview, answering_machine_detect: true, use_recordings: false)
        campaign.continue_on_amd.should be_falsey
      end

      it "should return false if answering machine detect false and recording  present" do
        campaign = create(:preview, answering_machine_detect: false, use_recordings: true)
        campaign.continue_on_amd.should be_falsey
      end
    end

    describe "hangup on amd" do
      it "should return true if answering machine detect and recording not present" do
        campaign = create(:preview, answering_machine_detect: true, use_recordings: false)
        campaign.hangup_on_amd.should be_truthy
      end

      it "should return false if answering machine detect and recording  present" do
        campaign = create(:preview, answering_machine_detect: true, use_recordings: true)
        campaign.hangup_on_amd.should be_falsey
      end

    end

  end

  describe "time period" do
    before(:each) do
      @campaign = create(:preview, :start_time => Time.new(2011, 1, 1, 9, 0, 0), :end_time => Time.new(2011, 1, 1, 21, 0, 0), :time_zone =>"Pacific Time (US & Canada)")
    end

    it "should allow callers to dial, if time not expired" do
      t1 = Time.parse("01/2/2011 10:00 -08:00")
      t2 = Time.parse("01/2/2011 09:00 -08:00")
      Time.stub(:now).and_return(t1, t1, t2, t2)
      @campaign.time_period_exceeded?.should == false
    end

    it "should not allow callers to dial, if time  expired" do
      t1 = Time.parse("01/2/2011 22:20 -08:00")
      t2 = Time.parse("01/2/2011 11:00 -08:00")
      t3 = Time.parse("01/2/2011 15:00 -08:00")
      Time.stub(:now).and_return(t1, t1, t2, t2, t3, t3)
      @campaign.time_period_exceeded?.should == true
    end
  end

   it "restoring makes it active" do
     campaign = create(:campaign, :active => false)
     campaign.restore
     campaign.should be_active
   end

   describe "scopes" do

     it "gives only active voter lists" do
       campaign = create(:preview)
       active_voterlist = create(:voter_list, :campaign => campaign, :active => true)
       inactive_voterlist = create(:voter_list, :campaign => campaign, :active => false)
       campaign.voter_lists.should == [active_voterlist]
     end

     it "returns campaigns having a session with the given caller" do
       caller = create(:caller)
       campaign = create(:preview)
       create(:caller_session, :campaign => campaign, :caller => caller)
       Campaign.for_caller(caller).should == [campaign]
     end

     it "sorts by the updated date" do
       Campaign.record_timestamps = false
       older_campaign = create(:power).tap { |c| c.update_attribute(:updated_at, 2.days.ago) }
       newer_campaign = create(:power).tap { |c| c.update_attribute(:updated_at, 1.day.ago) }
       Campaign.record_timestamps = true
       Campaign.by_updated.all.should include (newer_campaign)
       Campaign.by_updated.all.should include (older_campaign)

     end

     it "lists deleted campaigns" do
       deleted_campaign = create(:power, :active => false)
       other_campaign = create(:power, :active => true)
       Campaign.deleted.should == [deleted_campaign]
     end

     it "should return active campaigns" do
       campaign1 = create(:power)
       campaign2 = create(:preview)
       campaign3 = create(:predictive, :active => false)
       Campaign.active.should include(campaign1)
       Campaign.active.should include(campaign2)
     end
  end

  describe "cost_per_minute" do

    it "should be .09" do
      campaign = create(:preview)
      campaign.cost_per_minute.should eq(0.09)
    end

  end

  describe "callers_status" do

    before (:each) do
      @campaign = create(:preview)
      @caller_session1 = create(:webui_caller_session, campaign_id: @campaign.id, on_call:true, available_for_call: true)
      @caller_session2 = create(:webui_caller_session, on_call:true, available_for_call: false, campaign_id: @campaign.id)
    end

    it "should return callers logged in" do
      @campaign.callers_status[0].should eq(2)
    end

    it "should return callers on hold" do
      @campaign.callers_status[1].should eq(1)
    end

    it "should return callers on call" do
      @campaign.callers_status[2].should eq(1)
    end


  end

  describe "call_status" do

    it "should return attempts in wrapup" do
      campaign = create(:preview)
      caller_attempt1 = create(:call_attempt, wrapup_time: nil, created_at: 3.minutes.ago, status:  CallAttempt::Status::SUCCESS, campaign_id: campaign.id)
      caller_attempt2 = create(:call_attempt, wrapup_time: nil, created_at: 7.minutes.ago, status:  CallAttempt::Status::SUCCESS, campaign_id: campaign.id)
      campaign.call_status[0].should eq(1)
    end

    it "should return live calls" do
      campaign = create(:preview)
      caller_attempt1 = create(:call_attempt, wrapup_time: nil, created_at: 3.minutes.ago, status:  CallAttempt::Status::INPROGRESS, campaign_id: campaign.id)
      caller_attempt2 = create(:call_attempt, wrapup_time: nil, created_at: 7.minutes.ago, status:  CallAttempt::Status::INPROGRESS, campaign_id: campaign.id)
      campaign.call_status[2].should eq(1)
    end

    it "should return ringing_lines" do
      campaign = create(:preview)
      caller_attempt1 = create(:call_attempt, wrapup_time: nil, created_at: 12.seconds.ago, status:  CallAttempt::Status::RINGING, campaign_id: campaign.id)
      caller_attempt2 = create(:call_attempt, wrapup_time: nil, created_at: 7.minutes.ago, status:  CallAttempt::Status::RINGING, campaign_id: campaign.id)
      campaign.call_status[1].should eq(1)
    end



  end

  describe "current status" do
    it "should return campaign details" do
      campaign = create(:predictive)
      c1= create(:phones_only_caller_session, on_call: false, available_for_call: false, campaign: campaign)

      c2= create(:webui_caller_session, on_call: true, available_for_call: false, attempt_in_progress: create(:call_attempt, connecttime: Time.now), campaign: campaign, state: "paused")
      c3= create(:phones_only_caller_session, on_call: true, available_for_call: false, attempt_in_progress: create(:call_attempt, connecttime: Time.now), campaign: campaign, state: "voter_response")
      c4= create(:phones_only_caller_session, on_call: true, available_for_call: false, attempt_in_progress: create(:call_attempt, connecttime: Time.now), campaign: campaign, state: "wrapup_call")

      c5= create(:webui_caller_session, on_call: true, available_for_call: true, attempt_in_progress: create(:call_attempt, campaign: campaign, status: CallAttempt::Status::RINGING, created_at: Time.now), campaign: campaign)
      c6= create(:phones_only_caller_session, on_call: true, available_for_call: true, campaign: campaign)
      c7= create(:webui_caller_session, on_call: true, available_for_call: true, attempt_in_progress: create(:call_attempt, campaign: campaign, status: CallAttempt::Status::RINGING, created_at: Time.now), campaign: campaign)
      c8= create(:webui_caller_session, on_call: true, available_for_call: false, attempt_in_progress: create(:call_attempt), campaign: campaign, attempt_in_progress: create(:call_attempt, connecttime: Time.now), state: "connected")
      c9= create(:phones_only_caller_session, on_call: true, available_for_call: false, campaign: campaign, attempt_in_progress: create(:call_attempt, connecttime: Time.now), state: "conference_started_phones_only_predictive")

      c10= create(:webui_caller_session, on_call: true, available_for_call: true, attempt_in_progress: create(:call_attempt, connecttime: Time.now), campaign: campaign)
      RedisStatus.set_state_changed_time(campaign.id, "On hold", c2.id)
      RedisStatus.set_state_changed_time(campaign.id, "On hold", c5.id)
      RedisStatus.set_state_changed_time(campaign.id, "On hold", c6.id)
      RedisStatus.set_state_changed_time(campaign.id, "On hold", c7.id)

      RedisStatus.set_state_changed_time(campaign.id, "On call", c8.id)
      RedisStatus.set_state_changed_time(campaign.id, "On call", c9.id)

      RedisStatus.set_state_changed_time(campaign.id, "Wrap up", c3.id)
      RedisStatus.set_state_changed_time(campaign.id, "Wrap up", c4.id)
      RedisStatus.set_state_changed_time(campaign.id, "Wrap up", c10.id)

      campaign.current_status.should eq ({callers_logged_in: 9, on_call: 2, wrap_up: 3, on_hold: 4, ringing_lines: 2, available: 0})

    end
  end

  describe "within_recycle_rate?(obj)" do
    let(:duck_available1) do
      double('AvailableDuckVoter1', {
        last_call_attempt_time: 4.days.ago
      })
    end
    let(:duck_available2) do
      double('AvailableDuckVoter2', {
        last_call_attempt_time: 25.hours.ago
      })
    end
    let(:duck_available3) do
      double('AvailableDuckVoter3', {
        last_call_attempt_time: nil
      })
    end
    let(:duck_in_recycle_rate1) do
      double('UnavailableDuckVoter1', {
        last_call_attempt_time: 5.seconds.ago
      })
    end
    let(:duck_in_recycle_rate2) do
      double('UnavailableDuckVoter1', {
        last_call_attempt_time: 4.hours.ago
      })
    end
    let(:duck_in_recycle_rate3) do
      double('UnavailableDuckVoter1', {
        last_call_attempt_time: 23.hours.ago + 59.minutes
      })
    end
    let(:non_duck) do
      double('NonDuck')
    end
    let(:campaign) do
      create(:preview, {
        recycle_rate: 24
      })
    end

    it 'returns true iff obj.last_call_attempt_time > Campaign#recycle_rate.hours.ago' do
      campaign.within_recycle_rate?(duck_in_recycle_rate1).should be_truthy
      campaign.within_recycle_rate?(duck_in_recycle_rate2).should be_truthy
    end

    it 'returns true if obj.last_call_attempt_time = Campaign#recycle_rate.hours.ago' do
      campaign.within_recycle_rate?(duck_in_recycle_rate3).should be_truthy
    end

    it 'returns false if obj.last_call_attempt_time < Campaign#recycle_rate.hours.ago' do
      campaign.within_recycle_rate?(duck_available1).should be_falsey
      campaign.within_recycle_rate?(duck_available2).should be_falsey
    end

    it 'returns false if obj.last_call_attempt_time.nil?' do
      campaign.within_recycle_rate?(duck_available3).should be_falsey
    end

    it 'raises ArgumentError if obj does not respond to last_call_attempt_time' do
      expect{ campaign.within_recycle_rate?(non_duck) }.to raise_error{ ArgumentError }
    end
  end
end



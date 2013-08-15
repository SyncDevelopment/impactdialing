require "spec_helper"

describe Trial do

  describe "campaign_types" do
    it "should return preview and power and predictive modes" do
     Trial.new.campaign_types.should eq([Campaign::Type::PREVIEW, Campaign::Type::POWER, Campaign::Type::PREDICTIVE])
    end
  end

  describe "campaign_type_options" do
    it "should return preview and power modes" do
     Trial.new.campaign_type_options.should eq([[Campaign::Type::PREVIEW, Campaign::Type::PREVIEW], [Campaign::Type::POWER, Campaign::Type::POWER], 
      [Campaign::Type::PREDICTIVE, Campaign::Type::PREDICTIVE]])
    end
  end

  describe "campaign" do

    before(:each) do
      @account =  create(:account)            
      @account.reload
    end
    it "should allow predictive dialing mode for trial subscription" do
      campaign = build(:predictive, account: @account)
      campaign.save.should be_true      
    end

    it "should  allow preview dialing mode for trial subscription" do
      campaign = build(:preview, account: @account)
      campaign.save.should be_true
    end

    it "should  allow power dialing mode for trial subscription" do
      campaign = build(:power, account: @account)
      campaign.save.should be_true
    end
  end

  describe "transfer_types" do
    it "should return empty" do
      Trial.new.transfer_types.should eq([Transfer::Type::WARM, Transfer::Type::COLD])
    end
  end

  describe "transfers" do
    before(:each) do
      @account =  create(:account)
      @account.reload
    end

    it "should allow saving transfers" do
      script = build(:script, account: @account)
      script.transfers << build(:transfer, phone_number: "(203) 643-0521", transfer_type: "warm")      
      script.save!.should be_true      
    end
  end

  describe "caller groups" do
    describe "caller_groups_enabled?" do
      it "should say  enabled" do
        Trial.new.caller_groups_enabled?.should be_true
      end
    end

    describe "it should not allow caller groups for callers" do
      before(:each) do
        @account =  create(:account, record_calls: false)            
        @account.reload
      end

      it "should save caller groups" do        
        caller = build(:caller, account: @account, campaign: create(:preview, account: @account))
        caller.caller_group = build(:caller_group, campaign: create(:preview, account: @account))
        caller.save.should be_true        
      end
    end
  end

  describe "call recordings" do
    describe "call_recording_enabled?" do
      it "should say  enabled" do
        Trial.new.call_recording_enabled?.should be_true
      end
    end

    describe "it should  allow call recordings to be enabled" do
      before(:each) do
        @account =  create(:account, record_calls: false)     
        @account.reload           
      end

      it "should save" do
        @account.update_attributes(record_calls: true).should be_true        
      end
    end
  end

  describe "should debit call time" do
    before(:each) do
      @account =  create(:account, record_calls: false)   
      @account.reload   
    end

    it "should deduct from minutes used if minutes used greater than 0" do
      @account.subscription.debit(2.00).should be_true
      @account.subscription.minutes_utlized.should eq(2)
    end

    it "should not deduct from minutes used if minutes used greater than eq total minutes" do
      @account.subscription.update_attributes(minutes_utlized: 50)
      @account.subscription.debit(2.00).should be_false
      @account.subscription.reload
      @account.subscription.minutes_utlized.should eq(50)
    end

    it "should not deduct from minutes used if alloted minutes does not fall in subscription time range" do
      @account.subscription.update_attributes(minutes_utlized: 10)
      @account.subscription.update_attributes(subscription_start_date: (DateTime.now-40.days))
      @account.subscription.debit(2.00).should be_false
      @account.subscription.reload
      @account.subscription.minutes_utlized.should eq(10)
    end

  end

  describe "add more than 1 caller" do
    before(:each) do
      @account =  create(:account)      
      @account.reload
    end

    it "should not allow to add more than 1 caller " do
      @account.subscription.update_attributes(number_of_callers: 2).should be_false
      @account.subscription.errors[:base].should == ["Trial account can have only 1 caller"]
    end    
  end

  describe "upgrade from trial to basic" do
    before(:each) do
      @account =  create(:account, record_calls: true)      
      @account.reload      
    end

    it "should change record calls to false" do
      @account.subscription.upgrade(Subscription::Type::BASIC)
      @account.reload
      @account.record_calls.should be_false
    end

    it "should convert any predictive campaigns to preview" do
      create(:predictive, account: @account)
      @account.subscription.upgrade(Subscription::Type::BASIC)
      @account.reload
      @account.campaigns.first.type.should eq(Campaign::Type::PREVIEW)
    end

    it "should delete any transfers in scripts" do
      script = create(:script, account: @account)
      create(:transfer, phone_number: "(203) 643-0521", transfer_type: "warm", script: script)
      script.reload
      script.transfers.size.should eq(1)
      @account.subscription.upgrade(Subscription::Type::BASIC)
      @account.reload
      script.reload
      script.transfers.should eq([])
    end

    it "should add delta of minutes on upgrade" do
      date = DateTime.new(DateTime.now.year,DateTime.now.month,13)
      subscription_start_date  = date-10.days
      puts subscription_start_date
      @account.subscription.update_attributes(minutes_utlized: 10, subscription_start_date: subscription_start_date)
      @account.subscription.upgrade(Subscription::Type::BASIC,1,0)
      @account.reload
      @account.subscription.total_allowed_minutes.should eq(612)
    end

    it "should add delta of minutes on upgrade" do
      date = DateTime.new(DateTime.now.year,DateTime.now.month,13)
      subscription_start_date  = date-10.days
      puts subscription_start_date
      @account.subscription.update_attributes(minutes_utlized: 10, subscription_start_date: subscription_start_date)
      @account.subscription.upgrade(Subscription::Type::BASIC)
      @account.reload
      @account.subscription.total_allowed_minutes.should eq(612)
    end
  end

end

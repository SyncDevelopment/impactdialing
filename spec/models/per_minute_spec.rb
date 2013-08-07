require "spec_helper"

describe PerMinute do
    describe "campaign_types" do
    it "should return preview and power modes" do
     PerMinute.new.campaign_types.should eq([Campaign::Type::PREVIEW, Campaign::Type::POWER, Campaign::Type::PREDICTIVE])
    end
  end

  describe "campaign_type_options" do
    it "should return preview and power modes" do
     PerMinute.new.campaign_type_options.should eq([[Campaign::Type::PREVIEW, Campaign::Type::PREVIEW], [Campaign::Type::POWER, Campaign::Type::POWER],[Campaign::Type::PREDICTIVE, Campaign::Type::PREDICTIVE]])
    end
  end
  describe "campaign" do
    before(:each) do
      @account =  create(:account, record_calls: false)
      @account.reload      
      @account.subscription.upgrade("PerMinute")
      @account.reload
    end
    it "should  allow predictive dialing mode for per minute subscription" do
      campaign = build(:predictive, account: @account)
      campaign.save.should be_true
    end

    it "should  allow preview dialing mode for per minute subscription" do
      campaign = build(:preview, account: @account)
      campaign.save.should be_true
    end

    it "should  allow power dialing mode for per minute subscription" do
      campaign = build(:power, account: @account)
      campaign.save.should be_true
    end
  end

  describe "transfer_types" do
    it "should return warm and cold transfers" do
      PerMinute.new.transfer_types.should eq([Transfer::Type::WARM, Transfer::Type::COLD])
    end
  end

  describe "transfers" do
    before(:each) do
      @account =  create(:account, record_calls: false)
      @account.reload      
      @account.subscription.upgrade("PerMinute")
      @account.reload
    end
    it "should  allow saving transfers" do
      script = build(:script, account: @account)
      script.transfers << build(:transfer)
      script.save
      script.errors[:base].should == ["Your subscription does not allow transfering calls in this mode."]
    end
  end

  describe "caller groups" do
    describe "caller_groups_enabled?" do
      it "should say enabled" do
        PerMinute.new.caller_groups_enabled?.should be_true
      end
    end

    describe "it should  allow caller groups for callers" do
      before(:each) do
        @account =  create(:account, record_calls: false)
        @account.reload      
        @account.subscription.upgrade("PerMinute")
        @account.reload
      end
      it "should save caller with caller groups" do
        caller = build(:caller, account: @account)
        caller.caller_group = build(:caller_group)
        caller.save.should be_true
      end
    end
  end

  describe "call recordings" do
    describe "call_recording_enabled?" do
      it "should say  enabled" do
        PerMinute.new.call_recording_enabled?.should be_true
      end
    end

    describe "it should allow call recordings to be enabled" do
      before(:each) do
        @account =  create(:account, record_calls: false)
        @account.reload      
        @account.subscription.upgrade("PerMinute")
        @account.reload
      end
      it "should all record calls" do
        @account.update_attributes(record_calls: true).should be_true
      end
    end
    
  end

end

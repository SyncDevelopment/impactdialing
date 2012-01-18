require "spec_helper"

describe ReportsController do
  context 'when logged in' do
    let(:user) { Factory(:user) }

    before(:each) do
      login_as user
    end

    it "lists all active robo campaigns belonging to a user" do
      Factory(:campaign, :active => false, :account => user.account)
      Factory(:campaign, :active => true, :robo => false, :account => user.account)
      Factory(:campaign, :active => true, :account => Factory(:account))
      campaign = Factory(:campaign, :active => true, :robo => true, :account => user.account)
      get :index
      assigns(:campaigns).should == [campaign]
    end

    describe "Campaign Reports" do
      let(:recording_count) { 2 }
      let(:script) { Factory(:script) }
      let(:campaign) { Factory(:campaign, :active => true, :account => user.account, :script => script) }
      let(:recording1) { Factory(:robo_recording, :script => script, :name => "recording1") }
      let(:recording2) { Factory(:robo_recording, :script => script, :name => "recording2") }

      let(:response1) { Factory(:recording_response, :response => "Aye", :keypad => 1, :robo_recording => recording1) }
      let(:response2) { Factory(:recording_response, :response => "Nay", :keypad => 2, :robo_recording => recording1) }
      let(:response3) { Factory(:recording_response, :response => "Onward, Ho!", :keypad => 1, :robo_recording => recording2) }
      let(:response4) { Factory(:recording_response, :response => "Retreat", :keypad => 2, :robo_recording => recording2) }

      it "lists usage" do
        get :usage, :campaign_id => campaign.id
        assigns(:campaign).should == campaign
        assigns(:minutes).should_not be_nil
      end

      it "lists dial details" do
        voter1 = Factory(:voter, :campaign => campaign, :Phone =>"1234567891" , :result_date => Time.now,:call_attempts => [Factory(:call_attempt),Factory( :call_attempt, :voter => voter1, :campaign => campaign, :status => CallAttempt::Status::SUCCESS )])
        voter2 = Factory(:voter, :campaign => campaign, :Phone =>"1234567892")

        Factory(:call_response, :call_attempt => voter1.call_attempts.last, :robo_recording => recording1, :recording_response => response1)
        Factory(:call_response, :call_attempt => voter1.call_attempts.last, :robo_recording => recording2, :recording_response => response4)

        post :dial_details, :id => campaign.id, :format => 'csv',:voter_fields => ["Phone"], :custom_voter_fields => []
        assigns(:campaign).should == campaign

        response.should be_redirect
      end
    end
  end
end

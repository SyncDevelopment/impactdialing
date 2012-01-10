require "spec_helper"

describe CallerController do
  let(:account) { Factory(:account) }
  let(:user) { Factory(:user, :account => account) }
  let(:caller) { Factory(:caller, :account => account) }


  describe "preview dial" do
    let(:campaign) { Factory(:campaign, start_time: Time.now - 6.hours, end_time: Time.now + 6.hours) }

    before(:each) do
      login_as(caller)
    end

    it "pushes a preview voter to the caller" do
      session_key = "sdklsjfg923784"
      voter = Factory(:voter, :campaign => campaign)
      next_voter = Factory(:voter, :campaign => campaign)
      session = Factory(:caller_session, :campaign => campaign, :caller => caller, :session_key => session_key)
      channel = mock
      info = voter.info
      info[:fields]['status'] = CallAttempt::Status::READY
      Pusher.should_receive(:[]).with(session_key).and_return(channel)
      channel.should_receive(:trigger).with('caller_connected', info.merge(:dialer => campaign.predictive_type))
      post :preview_voter, :id => caller.id, :session_id => session.id
    end

    it "pushes a preview voter to the caller" do
      session_key = "some_key"
      voter = Factory(:voter, :campaign => campaign)
      next_voter = Factory(:voter, :campaign => campaign)
      session = Factory(:caller_session, :campaign => campaign, :caller => caller, :session_key => session_key)
      channel = mock
      info = voter.info
      info[:fields]['status'] = CallAttempt::Status::READY
      Pusher.should_receive(:[]).with(session_key).and_return(channel)
      channel.should_receive(:trigger).with('caller_connected', info.merge(:dialer => campaign.predictive_type))
      post :preview_voter, :id => caller.id, :session_id => session.id
    end

    it "connects to twilio before making a call" do
      session_key = "sdklsjfg923784"
      session = Factory(:caller_session, :caller=> caller, :session_key => session_key)
      CallerSession.stub(:find_by_session_key).with(session_key).and_return(session)
      session.stub(:call)
      Twilio.should_receive(:connect).with(anything, anything)
      get :preview_dial, :key => session_key, :voter_id => Factory(:voter).id
    end

    it "skips to the next voter to preview" do
      session_key = "sdklsjfg923784"
      voter = Factory(:voter, :campaign => campaign, "FirstName"=>'first')
      next_voter = Factory(:voter, :campaign => campaign, "FirstName"=>'last')
      session = Factory(:caller_session, :campaign => campaign, :caller => caller, :session_key => session_key)
      channel = mock
      info = next_voter.info
      info[:fields]['status'] = CallAttempt::Status::READY

      Pusher.should_receive(:[]).with(session_key).and_return(channel)
      channel.should_receive(:trigger).with('caller_connected', info.merge(:dialer => campaign.predictive_type))
      post :preview_voter, :id => caller.id, :session_id => session.id, :voter_id => voter.id
    end

    it "skips to the first undialed voter if the current voter context is the last" do
      session_key = "sdklsjfg923784"
      first_voter = Factory(:voter, :campaign => campaign, "FirstName"=>'first')
      last_voter = Factory(:voter, :campaign => campaign, "FirstName"=>'last')
      session = Factory(:caller_session, :campaign => campaign, :caller => caller, :session_key => session_key)
      channel = mock
      info = first_voter.info
      info[:fields]['status'] = CallAttempt::Status::READY

      Pusher.should_receive(:[]).with(session_key).and_return(channel)
      channel.should_receive(:trigger).with('caller_connected', info.merge(:dialer => campaign.predictive_type))
      post :preview_voter, :id => caller.id, :session_id => session.id, :voter_id => last_voter.id
    end

    it "makes a call to the voter" do
      caller_session = Factory(:caller_session, :caller => caller, :on_call => true, :available_for_call => true)
      voter = Factory(:voter)
      Twilio::Call.stub(:make)
      Twilio::Call.should_receive(:make).with(anything, voter.Phone,anything,anything).and_return("TwilioResponse"=> {"Call" => {"Sid" => 'sid'}})
      post :call_voter, :session_id => caller_session.id , :voter_id => voter.id, id: caller.id
    end

    it "pushes 'calling' to the caller" do
      session_key = "caller_session_key"
      campaign = Factory(:campaign, :start_time => Time.new("2000-01-01 01:00:00"), :end_time => Time.new("2000-01-01 23:00:00"))
      caller_session = Factory(:caller_session, :caller => caller, :on_call => true, :available_for_call => true, :session_key => session_key, :campaign => campaign)
      voter = Factory(:voter)
      channel = mock
      Twilio::Call.stub(:make).and_return("TwilioResponse"=> {"Call" => {"Sid" => 'sid'}})
      Pusher.should_receive(:[]).with(session_key).and_return(channel)
      channel.should_receive(:trigger).with('calling_voter', anything)
      post :call_voter, :session_id => caller_session.id , :voter_id => voter.id, id: caller.id
    end
  end

  describe "calling in" do

    it "terminates a callers session" do
      sid = "some_sid"
      session = Factory(:caller_session, :caller => caller, :campaign => Factory(:campaign), :available_for_call => true, :on_call => true, :sid => sid)
      post :end_session, :CallSid => sid
      session.reload.available_for_call.should be_false
      session.reload.on_call.should be_false
      response.body.should == Twilio::Verb.hangup
    end

    it "terminates a callers session when a caller has not been identified" do
      sid = "some_sid"
      session = Factory(:caller_session, :caller => caller, :campaign => Factory(:campaign), :available_for_call => true, :on_call => true)
      post :end_session, :CallSid => sid
      response.body.should == Twilio::Verb.hangup
    end

    it "pauses a callers session while an attempt is in progress" do
      session = Factory(:caller_session, :caller => caller, :campaign => Factory(:campaign), :available_for_call => false, :on_call => true, :voter_in_progress => Factory(:voter), :session_key => 'some_key')
      post :pause, :id => caller.id, :session_id => session.id, :attempt => nil
      response.body.should == session.pause_for_results
    end

    it "says wait message every fifth attempts when the voter is paused for results" do
      session = Factory(:caller_session, :caller => caller, :campaign => Factory(:campaign), :available_for_call => false, :on_call => true, :voter_in_progress => Factory(:voter), :session_key => 'some_key')
      post :pause, :id => caller.id, :session_id => session.id, :attempt => 5
      response.body.should == session.pause_for_results(5)
    end

    it "resets a callers session's conference while an attempt is in progress" do
      campaign = Factory(:campaign, :start_time => Time.new("2000-01-01 01:00:00"), :end_time => Time.new("2000-01-01 23:00:00"))
      campaign.callers << caller
      session = Factory(:caller_session, :caller => caller, :campaign => campaign, :available_for_call => false, :on_call => true, :session_key => "some_key")
      post :pause, :id => caller.id, :session_id => session.id
      response.body.should == session.start
    end

    it "hangups if caller is disconnected" do
      session = Factory(:caller_session, :caller => caller, :campaign => Factory(:campaign), :available_for_call => false, :on_call => false, :session_key => "some_key")
      post :pause, :id => caller.id, :session_id => session.id
      response.body.should == Twilio::Verb.hangup
    end

    it "finds the campaigns callers active session" do
      login_as(caller)
      campaign = Factory(:campaign)
      campaign.callers << caller
      session = Factory(:caller_session, :caller => caller, :session_key => 'key', :on_call => true, :available_for_call => true, :campaign => campaign)
      Factory(:caller_session, :caller => caller, :session_key => 'other_key', :on_call => true, :available_for_call => true, :campaign => Factory(:campaign))
      post :active_session, :id => caller.id, :campaign_id => campaign
      response.body.should == session.to_json
    end


    it "returns no session if caller not associated with a campaign" do
      login_as(caller)
      campaign = Factory(:campaign)
      session = Factory(:caller_session, :caller => caller, :session_key => 'key', :on_call => true, :available_for_call => true, :campaign => campaign)
      post :active_session, :id => caller.id, :campaign_id => campaign
      response.body.should == {:caller_session => {:id => nil}}.to_json
    end

    it "returns no session if the caller is not connected" do
      login_as(caller)
      campaign = Factory(:campaign)
      campaign.callers << caller
      Factory(:caller_session, :caller => caller, :session_key => 'key', :on_call => false, :available_for_call => true, :campaign => campaign)
      post :active_session, :id => caller.id, :campaign_id => campaign.id
      response.body.should == {:caller_session => {:id => nil}}.to_json
    end
  end

  describe "phones-only call" do
    let(:campaign) { Factory(:campaign, :robo => false, :predictive_type => 'preview') }
    let(:caller) { Factory(:caller, :is_phones_only => true, :name => "caller name", :pin => "78453", campaign:  campaign) }
    describe "preview mode" do
      before(:each) do
        @caller_session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => "sessionkey")
        @current_voter = Factory(:voter, :campaign => campaign)
      end

      it "add the caller to the conference and call to the voter, if caller press * " do
        Twilio::Call.stub(:make)
        Twilio::Call.should_receive(:make).with(anything, @current_voter.Phone, anything, anything).and_return("TwilioResponse"=> {"Call" => {"Sid" => 'sid'}})
        post :choose_voter, :id => caller.id, :session => @caller_session.id, :voter => @current_voter.id, :Digits => "*"
        response.body.should == @caller_session.phones_only_start
      end

      it "if caller press #, skip the voter then say the next voter name and ask for option" do
        next_voter = Factory(:voter, :campaign => campaign, :FirstName => "next voter first name", :LastName => "next voter last name")
        post :choose_voter, :id => caller.id, :session => @caller_session.id, :voter => @current_voter.id, :Digits => "#"
        response.body.should == Twilio::Verb.new do |v|
          v.gather(:numDigits => 1, :timeout => 10, :action => choose_voter_caller_url(caller, :session => @caller_session.id, :host => Settings.host, :port => Settings.port, :voter => next_voter.id), :method => "POST", :finishOnKey => "5") do
            v.say I18n.t(:read_voter_name, :first_name => next_voter.FirstName, :last_name => next_voter.LastName)
          end
        end.response
        @current_voter.reload.skipped_time.should_not be_nil
        @current_voter.reload.status.should == 'not called'
      end
    end

    describe "progressive mode" do
      it "add the caller to the conference and make the call to voter" do
        campaign = Factory(:campaign, :robo => false, :predictive_type => 'preview')
        campaign.callers << caller
        caller_session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => "sessionkey")
        voter = Factory(:voter, :campaign => campaign)

        Twilio::Call.stub(:make)
        Twilio::Call.should_receive(:make).with(anything, voter.Phone, anything, anything).and_return("TwilioResponse"=> {"Call" => {"Sid" => 'sid'}})
        post :phones_only_progressive, :id => caller.id, :session_id => caller_session.id, :voter_id => voter.id
        response.body.should == caller_session.phones_only_start
      end
    end

    it "ask caller to select options, i.e * for dialing or # for instructions" do
      campaign = Factory(:campaign, :robo => false, :predictive_type => 'preview')
      campaign.callers << caller
      caller_session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => "sessionkey")
      post :choose_instructions_option, :id => caller.id, :session => caller_session.id, :Digits => "*"
      response.body.should == caller.instruction_choice_result("*", caller_session)
    end

  end
  
  it "read re-assiged msg when caller reassigned to another campaign" do
    campaign = Factory(:campaign, :robo => false, :predictive_type => 'preview')
    campaign.callers << caller
    caller_session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => "sessionkey")
    post :phones_only, :campaign_reassigned => "true", :session_id => caller_session.id
    response.body.should == caller_session.read_campaign_reassign_msg
  end

  it "logs out" do
    login_as(caller)
    post :logout
    session[:caller].should_not be
    response.should redirect_to(caller_login_path)
  end

  describe "phones only" do
    let(:account) { Factory(:account) }
    let(:user) { Factory(:user, :account => account) }
    let(:script) { Factory(:script) }
    let(:campaign) { Factory(:campaign, :account => account, :robo => false, :use_web_ui => true, :script => script) }
    let(:caller) { Factory(:caller, :campaign => campaign, :account => account) }
    let(:voter) { Factory(:voter, :campaign => campaign) }
    let(:caller_session) { Factory(:caller_session, :campaign => campaign, :session_key => "some_key", :caller => caller, :available_for_call => true, :on_call => true) }
    let(:call_attempt) { Factory(:call_attempt, :voter => voter, :campaign => campaign, :caller_session => caller_session) }
    let(:first_question) { Factory(:question, :script => script) }

    before(:each) do
      caller_session.update_attribute(:voter_in_progress, voter)
    end

    it "gathers responses" do
      Factory(:possible_response, :keypad => 1, :question => first_question, :value => "value")
      post :gather_response, :id => caller.id, :session_id => caller_session.id, :question_id => first_question.id, :Digits => "1"
      voter.answers.size.should == 1
    end

    it "reads out the next question" do
      Factory(:possible_response, :keypad => 1, :question => first_question, :value => "value")
      next_question = Factory(:question, :script => script)
      Factory(:possible_response, :question => next_question, :keypad => "1", :value => "value")

      post :gather_response, :id => caller.id, :session_id => caller_session.id, :question_id => first_question.id, :Digits => "1"
      response.body.should == next_question.read(caller_session)
    end

    it "places the voter in a conference when all questions are answered" do
      Factory(:possible_response, :keypad => 1, :question => first_question, :value => "value")
      post :gather_response, :id => caller.id, :session_id => caller_session.id, :question_id => first_question.id, :Digits => "1"
      response.body.should == call_attempt.caller_session.start
    end

    it "places the caller in a new conference if there is no voter in progress" do
      caller_session.update_attribute(:voter_in_progress, nil)
      post :gather_response, :id => caller.id, :session_id => caller_session.id
      response.body.should == caller_session.start
    end

    it "ask caller to choose voter if campaign type is either preview or progressive" do
      campaign_preview = Factory(:campaign, :account => account, :robo => false, :use_web_ui => true, :script => script, :predictive_type => "preview")
      phones_only_caller = Factory(:caller, :is_phones_only => true, :campaign => campaign_preview)
      caller_session2 = Factory(:caller_session, :campaign => campaign_preview, :session_key => "some_key", :caller => phones_only_caller, :available_for_call => true, :on_call => true)
      post :gather_response, :id => phones_only_caller.id, :session_id => caller_session2.id, :question_id => first_question.id, :Digits => "1"
      response.body.should == caller_session2.ask_caller_to_choose_voter
    end


    it "hangs up if the caller_session is disconnected" do
      caller_session.update_attributes(:available_for_call => false, :on_call => false)
      post :gather_response, :id => caller.id, :session_id => caller_session.id
      response.body.should == Twilio::Verb.hangup
    end

  end
end

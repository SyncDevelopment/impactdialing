require "spec_helper"

describe Call do

  it "should start a call in initial state" do
    call = Factory(:call)
    call.state.should eq('initial')
  end

  describe "initial" do

    describe "incoming call answered by human" do

      before(:each) do
        @caller = Factory(:caller)
        @script = Factory(:script)
        @campaign =  Factory(:preview, script: @script)
        @caller_session = Factory(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        @voter  = Factory(:voter, campaign: @campaign, caller_session: @caller_session)
        @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign)
      end
      
      it "should move to the connected state" do
        call = Factory(:call, call_attempt: @call_attempt, call_status: 'in-progress')
        @call_attempt.should_receive(:connect_call)
        @call_attempt.should_receive(:publish_voter_connected)
        call.incoming_call!
        call.state.should eq('connected')
      end
      
      it "should start a conference in connected state" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, call_status: 'in-progress')
        @call_attempt.should_receive(:connect_call)
        @call_attempt.should_receive(:caller_session_key)
        @call_attempt.should_receive(:redis_caller_session).and_return("1")

        @call_attempt.should_receive(:publish_voter_connected)
        call.incoming_call!
        call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"false\" action=\"https://#{Settings.host}/calls/#{call.id}/flow?event=disconnect\" record=\"false\"><Conference waitUrl=\"hold_music\" waitMethod=\"GET\" beep=\"false\" endConferenceOnExit=\"true\" maxParticipants=\"2\"/></Dial></Response>")
      end


    end

    describe "incoming call answered by human that need to be abandoned" do
      before(:each) do
        @caller = Factory(:caller)
        @script = Factory(:script)
        @campaign =  Factory(:predictive, script: @script)
        @caller_session = Factory(:caller_session, caller: @caller, on_call: false, available_for_call: false, campaign: @campaign)
        @voter = Factory(:voter, campaign: @campaign)
        @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign)
      end
  
      it "should move to the abandoned state" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, call_status: 'in-progress')
        @call_attempt.should_receive(:caller_available?).and_return(false)
        @call_attempt.should_receive(:caller_not_available?).and_return(true)
        @call_attempt.should_receive(:abandon_call)
        @call_attempt.should_receive(:redirect_caller)
        call.incoming_call!
        call.state.should eq('abandoned')
      end
      
      it "should return hangup twiml for abandoned users" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, call_status: 'in-progress')
        @call_attempt.should_receive(:caller_available?).and_return(false)
        @call_attempt.should_receive(:caller_not_available?).and_return(true)
        @call_attempt.should_receive(:abandon_call)
        @call_attempt.should_receive(:redirect_caller)
        call.incoming_call!
        call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
      end
  
    end
  
describe "incoming call answered by machine" do

    before(:each) do
      @script = Factory(:script)
      @campaign =  Factory(:preview, script: @script, use_recordings: false)
      @voter = Factory(:voter, campaign: @campaign)
      @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign)
    end


    it "should move to state call_answered_by_machine" do
      call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt)
      @campaign.update_attribute(:use_recordings, true)
      @call_attempt.should_receive(:process_answered_by_machine)
      @call_attempt.should_receive(:redirect_caller)      
      call.incoming_call!
      call.state.should eq('call_answered_by_machine')
    end

    it "should render the user recording and hangup if user recording present" do
      recording = Factory(:recording)
      @campaign.update_attributes(recording_id: recording.id, use_recordings: true)
      call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt)
      @call_attempt.should_receive(:process_answered_by_machine)
      @call_attempt.should_receive(:redirect_caller)            
      call.incoming_call!
      call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Play>http://s3.amazonaws.com/impactdialing_production/test/uploads/unknown/#{recording.id}.mp3</Play><Hangup/></Response>")
    end

    it "should render  and hangup if user recording is not present" do
      call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt)
      call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt)
      @call_attempt.should_receive(:process_answered_by_machine)
      @call_attempt.should_receive(:redirect_caller)                  
      call.incoming_call!
      call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
    end

  end
   
 describe "twilio detecting real user as answering machine" do
     before(:each) do
       @script = Factory(:script)
       @campaign =  Factory(:campaign, script: @script)
       @voter = Factory(:voter, campaign: @campaign)
       @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign)
     end

     it "should update wrapuptime for call attempt" do
       call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt, call_status: "success")
       call.call_ended!
       call.state.should eq('abandoned')
     end


     it "should should render hangup to the lead" do
       call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt, call_status: "success")
       call.call_ended!
       call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
     end
   end
  
  describe "end call that dint connect" do

    before(:each) do
     @script = Factory(:script)
     @campaign =  Factory(:campaign, script: @script)
     @caller = Factory(:caller)
     @caller_session = Factory(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
     @voter = Factory(:voter, campaign: @campaign)
     @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign, caller_session: @caller_session)
    end

    it "should update call attempt status" do            
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, call_status: 'busy', state: "initial")
      @call_attempt.should_receive(:end_unanswered_call)
      @call_attempt.should_receive(:redirect_caller)
      call.call_ended!
      call.state.should eq('call_not_answered_by_lead')
    end

  end
  
  
  end
  
  describe "connected" do
  
     describe "hangup "  do
       before(:each) do
         @script = Factory(:script)
         @campaign =  Factory(:campaign, script: @script)
         @voter = Factory(:voter, campaign: @campaign)
         @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign)
       end
  
       it "should render nothing" do
         call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'connected')
         @call_attempt.should_receive(:end_running_call)
         call.hangup!
         call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response></Response>")
       end
  
       it "should move to hungup state" do
         call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'connected')
         @call_attempt.should_receive(:end_running_call)
         call.hangup!
         call.state.should eq('hungup')
       end
     end

   describe "disconnect"  do
     before(:each) do
       @script = Factory(:script)
       @campaign =  Factory(:campaign, script: @script)
       @caller_session = Factory(:caller_session)
       @voter = Factory(:voter, campaign: @campaign, caller_session: @caller_session)
       @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign, caller_session: @caller_session)
     end

     it "should move to disconnected state" do
       call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'connected')
       @call_attempt.should_receive(:disconnect_call)
       @call_attempt.should_receive(:publish_voter_disconnected)
       call.disconnect!
       call.state.should eq('disconnected')
     end

     it "should hangup twiml" do
       call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'connected')
       @call_attempt.should_receive(:disconnect_call)
       @call_attempt.should_receive(:publish_voter_disconnected)
       call.disconnect!
       call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
     end
   end


  end
  
  describe "hungup" do
  
    describe "disconnect call" do
      before(:each) do
       @script = Factory(:script)
       @campaign =  Factory(:campaign, script: @script)
       @caller_session = Factory(:caller_session)
       @voter = Factory(:voter, campaign: @campaign, caller_session: @caller_session)
  
       @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign, caller_session: @caller_session)
      end
  
      it "should change status to disconnected" do
       call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'hungup')
       @call_attempt.should_receive(:disconnect_call)
       @call_attempt.should_receive(:publish_voter_disconnected)
       call.disconnect!
       call.state.should eq("disconnected")
      end
  
      it "should hangup twiml" do
       call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'hungup')
       @call_attempt.should_receive(:disconnect_call)       
       @call_attempt.should_receive(:publish_voter_disconnected)
       call.disconnect!
       call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
      end  
    end
  
  end
  
  describe "disconnected" do
  
    describe "call_answered_by_lead" do
      before(:each) do
       @script = Factory(:script)
       @campaign =  Factory(:campaign, script: @script)
       @voter = Factory(:voter, campaign: @campaign)
       @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign)
      end
  
      it "should update call status" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'disconnected', call_status: 'success')
        call.call_ended!
        call.state.should eq("call_answered_by_lead")
      end
  
      it "should return hangup twmil" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'disconnected', call_status: 'success')
        call.call_ended!
        call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
      end
  
    end
  
    describe "call not answered by lead" do
      before(:each) do
       @script = Factory(:script)
       @campaign =  Factory(:campaign, script: @script)
       @voter = Factory(:voter, campaign: @campaign)
       @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign)
      end
  
  
      it "should update call status" do
        call = Factory(:call, call_attempt: @call_attempt, state: 'disconnected', call_status: 'busy')
        @call_attempt.should_receive(:end_unanswered_call)
        @call_attempt.should_receive(:redirect_caller)
        call.call_ended!
        call.state.should eq("call_not_answered_by_lead")
      end
  
      it "should render hangup twiml" do
        call = Factory(:call, call_attempt: @call_attempt, state: 'disconnected', call_status: 'busy')
        @call_attempt.should_receive(:end_unanswered_call)
        @call_attempt.should_receive(:redirect_caller)
        call.call_ended!
        call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
      end
    
    end
  end
  
  describe "call_answered_by_machine" do
  
    describe "call_ended for answered by machine" do
  
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:campaign, script: @script)
        @voter = Factory(:voter, campaign: @campaign)
        @caller_session = Factory(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign, caller_session: @caller_session, status: CallAttempt::Status::HANGUP)
      end
  
  
      it "should  update call state " do
        call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt, state: 'call_answered_by_machine')
        @call_attempt.should_receive(:end_answered_by_machine)
        call.call_ended!
        call.state.should eq('call_end_machine')
      end
  
      it "should  return hangup twiml" do
        call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt, state: 'call_answered_by_machine')
        @call_attempt.should_receive(:end_answered_by_machine)
        call.call_ended!
        call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
      end
    end
  
  end

  describe "call_answered_by_lead" do
    describe "submit_result" do
  
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:campaign, script: @script)
        @voter = Factory(:voter, campaign: @campaign)
        @caller_session = Factory(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign, caller_session: @caller_session)
      end
  
      it "should update call state" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'call_answered_by_lead', all_states: "")
        @call_attempt.should_receive(:wrapup_now)
        @call_attempt.should_receive(:redirect_caller)
        @call_attempt.should_receive(:publish_moderator_response_submited)
        call.submit_result!
        call.state.should eq('wrapup_and_continue')
      end
    end
  
    describe "submit_result_and_stop" do
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:campaign, script: @script)
        @voter = Factory(:voter, campaign: @campaign)
        @caller_session = Factory(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign, caller_session: @caller_session)
      end
      
      it "should update call state" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'call_answered_by_lead', all_states: "")
        @call_attempt.should_receive(:wrapup_now)
        @call_attempt.should_receive(:end_caller_session)
        @call_attempt.should_receive(:publish_moderator_response_submited)        
        call.submit_result_and_stop!
        call.state.should eq('wrapup_and_stop')
      end
    end
  end

end
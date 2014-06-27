require "spec_helper"

describe CallsController do
  let(:recording){ create(:recording) }
  let(:campaign){ create(:power, {recording: recording}) }
  let(:caller){ create(:caller, {campaign: campaign}) }
  let(:caller_session){ create(:webui_caller_session, {caller: caller}) }
  let(:voter){ create(:voter, {campaign: campaign}) }
  let(:call_attempt){ create(:call_attempt, {voter: voter, campaign: campaign, caller_session: caller_session}) }
  let(:call){ create(:call, {call_attempt: call_attempt}) }

  describe 'TwiML endpoints' do
    describe "#call_ended" do
      it "should only render twiml if call connected" do
        caller                      = create(:caller)
        call                        = create(:call, answered_by: "human", state: 'initial', call_status: "completed")
        caller_session              = create(:webui_caller_session, {caller: caller})
        call_attempt                = call.call_attempt
        call_attempt.caller_session = caller_session
        call_attempt.caller         = caller
        call_attempt.save!

        post :call_ended, CallStatus: "completed", id: call.id
        RedisCallFlow.should_not_receive(:push_to_not_answered_call_list)
        response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
      end
    end

    describe '#play_message' do
      before do
        call.stub(:enqueue_call_flow).with(CallerPusherJob, [caller_session.id, 'publish_message_drop_success'])
        call.stub(:enqueue_call_flow).with(Providers::Phone::Jobs::DropMessageRecorder, [call.id, 1])
        Call.stub(:find_by_id){ call }
      end

      it 'updates recording info on the associated CallAttempt' do
        call.should_receive(:enqueue_call_flow).with(Providers::Phone::Jobs::DropMessageRecorder, [call.id, 1]).once
        post :play_message, id: call.id
      end

      it 'sends a message_drop_success event via Pusher' do
        call.should_receive(:enqueue_call_flow).with(CallerPusherJob, [caller_session.id, 'publish_message_drop_success']).once
        post :play_message, id: call.id
      end

      it 'renders TwiML to play the associated recording' do
        recording.file.stub(:url){ '/oolala.jive' }
        post :play_message, id: call.id
        response.body.should =~ /#{recording.file.url}/
      end
    end
  end

  describe 'Browser endpoints' do
    describe '#drop_message' do
      it 'begins the drop message process' do
        Call.stub(:find_by_id){ call }
        call.should_receive(:enqueue_call_flow).with(Providers::Phone::Jobs::DropMessage, [call.id])
        post :drop_message, id: call.id
      end
    end
  end
end
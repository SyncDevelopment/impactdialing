require "spec_helper"

describe CallerController do

  before do
    WebMock.disable_net_connect!
  end

  let(:account) { create(:account) }
  let(:user) { create(:user, :account => account) }

  describe "preview dial" do
    let(:campaign) { create(:campaign, start_time: Time.now - 6.hours, end_time: Time.now + 6.hours) }

    before(:each) do
      @caller = create(:caller, :account => account)
      login_as(@caller)
    end

    it "logs out" do
      @caller = create(:caller, :account => account)
      login_as(@caller)
      post :logout
      session[:caller].should_not be
      response.should redirect_to(caller_login_path)
    end

  end

  describe "start calling" do
    it "should start a new caller conference" do
      account = create(:account)
      campaign = create(:predictive, account: account)
      caller = create(:caller, campaign: campaign, account: account)
      caller_identity = create(:caller_identity)
      caller_session = create(:webui_caller_session, session_key: caller_identity.session_key, caller_type: CallerSession::CallerType::TWILIO_CLIENT, caller: caller, campaign: campaign)
      Caller.should_receive(:find).and_return(caller)
      caller.should_receive(:create_caller_session).and_return(caller_session)
      RedisPredictiveCampaign.should_receive(:add).with(caller.campaign_id, caller.campaign.type)
      post :start_calling, caller_id: caller.id, session_key: caller_identity.session_key, CallSid: "abc"
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"true\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{caller.id}/pause?session_id=#{caller_session.id}\"><Conference startConferenceOnEnter=\"false\" endConferenceOnExit=\"true\" beep=\"true\" waitUrl=\"hold_music\" waitMethod=\"GET\"/></Dial></Response>")
    end
  end

  describe "call voter" do
    it "should call voter" do
      account = create(:account)
      campaign =  create(:predictive, account: account)
      caller = create(:caller, campaign: campaign, account: account)
      caller_identity = create(:caller_identity)
      voter = create(:voter, campaign: campaign)
      caller_session = create(:webui_caller_session, session_key: caller_identity.session_key, caller_type: CallerSession::CallerType::TWILIO_CLIENT, caller: caller)
      Caller.should_receive(:find).and_return(caller)
      caller.should_receive(:calling_voter_preview_power)
      post :call_voter, id: caller.id, voter_id: voter.id, session_id: caller_session.id
    end
  end

  describe "kick id:, caller_session:, participant_type:" do
    let(:account){ create(:account) }
    let(:campaign){ create(:predictive, account: account) }
    let(:caller){ create(:caller, campaign: campaign, account: account) }
    let(:caller_identity){ create(:caller_identity) }
    let(:voter){ create(:voter, campaign: campaign) }

    let(:transfer_attempt) do
      create(:transfer_attempt)
    end
    let(:caller_session) do
      create(:webui_caller_session, {
        session_key: caller_identity.session_key,
        caller_type: CallerSession::CallerType::TWILIO_CLIENT,
        caller: caller,
        campaign: campaign,
        sid: '123abc',
        transfer_attempts: [transfer_attempt]
      })
    end
    let(:url_opts) do
      {
        host: Settings.twilio_callback_host,
        port: Settings.twilio_callback_port,
        protocol: "http://",
        session_id: caller_session.id
      }
    end
    let(:conference_sid){ 'CFww834eJSKDJFjs328JF92JSDFwe' }
    let(:conference_name){ caller_session.session_key }
    let(:valid_response) do
      double('TwilioResponseObject', {
        :[] => {
          'TwilioResponse' => {}
        },
        :conference_sid => conference_sid
      })
    end
    let(:valid_params) do
      {
        id: caller.id,
        caller_session_id: caller_session.id
      }
    end
    before do
      session[:caller] = caller.id
      stub_twilio_conference_by_name_request
    end
    context 'participant_type: "caller"' do
      let(:call_sid){ caller_session.sid }
      before do
        stub_twilio_kick_participant_request
        post_body = pause_caller_url(caller, url_opts)
        stub_twilio_redirect_request(post_body)
        post :kick, valid_params.merge(participant_type: 'caller')
      end

      it 'kicks caller off conference' do
        @kick_request.should have_been_made
      end
      it 'redirects caller to pause url' do
        @redirect_request.should have_been_made
      end
      it 'renders nothing' do
        response.body.should be_blank
      end
    end

    context 'participant_type: "transfer"' do
      let(:call_sid){ transfer_attempt.sid }
      before do
        stub_twilio_kick_participant_request
        post :kick, valid_params.merge(participant_type: 'transfer')
      end

      it 'kicks transfer off conference' do
        @kick_request.should have_been_made
      end
      it 'renders nothing' do
        response.body.should be_blank
      end
    end
  end

  describe '#pause session_id:, CallSid:, clear_active_transfer:' do
    let(:caller_session) do
      create(:webui_caller_session)
    end
    let(:session_key){ caller_session.session_key }
    let(:session_id){ caller_session.id }

    context 'caller arrives here after disconnecting from the lead' do
      before do
        RedisCallerSession.active_transfer(session_key).should be_nil
        post :pause, session_id: session_id
      end
      it 'Says: "Please enter your call results."' do
        response.body.should have_content 'Please enter your call results.'
      end
    end

    context 'caller arrives here after dialing a warm transfer' do
      before do
        RedisCallerSession.activate_transfer(session_key)
        RedisCallerSession.active_transfer(session_key).should eq '1'
        post :pause, session_id: session_id
      end
      after do
        RedisCallerSession.deactivate_transfer(session_key)
      end
      it 'Plays silence for 0.5 seconds' do
        response.body.should include '<Play digits="w"/>'
      end
    end

    context 'caller arrives here after leaving a warm transfer' do
      before do
        RedisCallerSession.activate_transfer(session_key)
        RedisCallerSession.active_transfer(session_key).should eq '1'
        post :pause, session_id: session_id, clear_active_transfer: true
      end
      after do
        RedisCallerSession.deactivate_transfer(session_key)
      end
      it 'clears the active transfer flag' do
        RedisCallerSession.active_transfer(session_key).should be_nil
      end
      it 'Plays silence for 0.5 seconds' do
        response.body.should include '<Play digits="w"/>'
      end
    end
  end
end

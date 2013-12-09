require 'spec_helper'

describe ModeratedSession do
  before do
    WebMock.disable_net_connect!
  end

  describe '.switch_mode(moderator, caller_session, type)' do
    let(:user) do
      create(:user)
    end
    let(:campaign) do
      create(:power, {account: user.account})
    end
    let(:call_attempt) do
      create(:call_attempt, {
        campaign: campaign,
        status: 'Call in progress'
      })
    end
    let(:voter) do
      create(:voter, {
        campaign: campaign,
        call_attempts: [call_attempt]
      })
    end
    let(:caller) do
      create(:caller, {
        campaign: campaign
      })
    end
    let(:caller_session) do
      create(:webui_caller_session, {
        campaign: campaign,
        caller: caller,
        voter_in_progress: voter,
        session_key: 'caller_session:session_key:abc123'
      })
    end
    let(:call_sid){ 'callsid:zyx987' }
    let(:moderator) do
      create(:moderator, {
        account: user.account,
        caller_session: nil,
        call_sid: call_sid
      })
    end
    let(:moderated_session_double) do
      double('ModeratedSession', {
        update_caller_session: nil,
        toggle_mute: nil,
        msg: ''
      })
    end
    let(:type){ 'breakin' }
    let(:conference_name){ caller_session.session_key }
    let(:conference_sid){ 'CFww834eJSKDJFjs328JF92JSDFwe' }

    before do
      stub_twilio_conference_by_name_request
      stub_twilio_unmute_participant_request
    end

    it 'loads a new instance of self' do
      ModeratedSession.should_receive(:new){ moderated_session_double }
      ModeratedSession.switch_mode(moderator, caller_session, type)
    end
    it 'updates the moderator to the caller_session' do
      moderator.caller_session_id.should_not eq caller_session.id
      ModeratedSession.switch_mode(moderator, caller_session, type)
      moderator.caller_session_id.should eq caller_session.id
    end
    it 'adds the moderator in unmute mode' do
      ModeratedSession.switch_mode(moderator, caller_session, type)
      @unmute_participant_request.should have_been_made
    end
    context 'status messages' do
      it 'when status of last voter call attempt is not "Call in progress" returns a Status message that the caller is not on a call' do
        ca = voter.call_attempts.first
        ca.status = 'Ringing'
        ca.save
        msg = ModeratedSession.switch_mode(moderator, caller_session, type)
        msg.should eq 'Status: Caller is not connected to a lead.'
      end
      it 'when status of last voter call attempt is "Call in progress" returns a Status message w/ the caller identity and monitor mode' do
        msg = ModeratedSession.switch_mode(moderator, caller_session, type)
        msg.should eq "Status: Monitoring in breakin mode on #{caller_session.caller.identity_name}."
      end
    end
    context 'type != "breakin"' do
      let(:type){ 'listen' }
      before do
        stub_twilio_mute_participant_request
      end
      it 'adds the moderator in unmute mode' do
        ModeratedSession.switch_mode(moderator, caller_session, type)
        @mute_participant_request.should have_been_made
      end
    end
  end
end

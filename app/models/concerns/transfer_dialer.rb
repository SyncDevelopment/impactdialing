class TransferDialer
  attr_reader :transfer, :transfer_attempt, :caller_session, :call, :voter

private
  def warm_transfer?
    types = [
      transfer_attempt.transfer_type,
      transfer.transfer_type
    ]
    types.map!{|str| str.try(:downcase)}
    types.include? Transfer::Type::WARM
  end

  def transfer_attempt_dialed(response)
    if response.error?
      attempt_attrs = {status: CallAttempt::Status::FAILED}
    else
      attempt_attrs = {sid: response.call_sid}
      activate_transfer
    end
    transfer_attempt.update_attributes(attempt_attrs)
  end

  def activate_transfer
    if warm_transfer?
      RedisCallerSession.activate_transfer(caller_session.session_key, transfer_attempt.session_key)
    end
  end

  def transfer_attempt_connected
    transfer_attempt.update_attribute(:connecttime, Time.now)
  end

  def create_transfer_attempt
    transfer.transfer_attempts.create({
      session_key: generate_session_key,
      campaign_id: caller_session.campaign_id,
      status: CallAttempt::Status::RINGING,
      caller_session_id: caller_session.id,
      call_attempt_id: call.call_attempt.id,
      transfer_type: transfer.transfer_type
    })
  end

  def generate_session_key
    return secure_digest(Time.now, (1..10).map{ rand.to_s })
  end

  def secure_digest(*args)
    return Digest::SHA1.hexdigest(args.flatten.join('--'))
  end

  def hangup_xml
    return Twilio::TwiML::Response.new {|r| r.Hangup }.text
  end

public
  def initialize(transfer)
    @transfer = transfer
  end

  def deactivate_transfer(session_key)
    RedisCallerSession.deactivate_transfer(session_key)
  end

  def dial(caller_session, call)
    @caller_session   = caller_session
    @call             = call
    @transfer_attempt = create_transfer_attempt

    deactivate_transfer(caller_session.session_key)
    # twilio makes synchronous callback requests so redis flag must be set
    # before calls are made if the flags are to handle callback requests
    params   = Providers::Phone::Call::Params::Transfer.new(transfer, :connect, transfer_attempt)
    response = Providers::Phone::Call.make(params.from, params.to, params.url, params.params, Providers::Phone.default_options)
    transfer_attempt_dialed(response)

    return {
      type: transfer.transfer_type,
      status: transfer_attempt.status
    }
  end

  def end
  end

  def connect(transfer_attempt)
    @transfer_attempt = transfer_attempt
    @caller_session = transfer_attempt.caller_session

    transfer_attempt_connected

    # todo: refactor workflow to queue call redirects and return TwiML faster

    # Publish transfer_type
    caller_session.publish('transfer_connected', {type: transfer_attempt.transfer_type})
    # Update current callee call with Twilio to transfers#callee, which renders conference xml
    params = Providers::Phone::Call::Params::Transfer.new(transfer, :callee, transfer_attempt)
    Providers::Phone::Call.redirect(params.call_sid, params.url, Providers::Phone.default_options)
    # todo: handle failures of above redirect
    if warm_transfer?
      # Keep the caller on the conference.
      # Update current caller call with Twilio to transfers#caller, which renders conference xml
      params = Providers::Phone::Call::Params::Transfer.new(transfer, :caller, transfer_attempt)
      Providers::Phone::Call.redirect(params.call_sid, params.url, Providers::Phone.default_options)
      # todo: handle failures of above redirect
      caller_session.publish("warm_transfer",{})
    else
      ##
      # This redirect is unnecessary because Caller#kick redirects to pause_caller_url.
      # Furthermore, the Dial:action for Transfer#caller is pause_caller_url.
      if RedisCallerSession.any_active_transfers?(caller_session.session_key)
        Providers::Phone::Call.redirect_for(caller_session, :pause)
      end
      # todo: handle failures of above redirect
      caller_session.publish("cold_transfer",{})
    end

    phone_params = Providers::Phone::Call::Params::Transfer.new(transfer_attempt.transfer, :disconnect, transfer_attempt)

    return Twilio::TwiML::Response.new do |r|
      # The action url for Dial will be called by Twilio when the dialed party hangs up
      r.Dial :hangupOnStar => 'false', :action => phone_params.url, :record => caller_session.campaign.account.record_calls do |d|
        d.Conference transfer_attempt.session_key, :waitUrl => HOLD_MUSIC_URL, :waitMethod => 'GET', :beep => false, :endConferenceOnExit => false
      end
    end.text
  end
end

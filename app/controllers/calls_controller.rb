class CallsController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :parse_params
  before_filter :find_and_update_call, :only => [:destroy, :incoming, :call_ended, :disconnected]
  before_filter :find_and_update_answers_and_notes_and_scheduled_date, :only => [:submit_result, :submit_result_and_stop]
  before_filter :find_call, :only => [:hangup, :call_ended, :drop_message, :play_message]


  # TwiML
  def incoming
    live_call = CallFlow::Call.new(params)
    live_call.update_history(:incoming)

    unless params['ErrorCode'] and params['ErrorUrl']
      xml = @call.incoming_call(params)
    else
      xml = @call.incoming_call_failed(params)
    end
    render xml: xml
  end

  # TwiML
  def call_ended
    render xml:  @call.call_ended(params['campaign_type'], params)
  end

  # TwiML
  def disconnected
    unless @call.cached_caller_session.nil?
      RedisCallFlow.push_to_disconnected_call_list(@call.id, RedisCall.recording_duration(@call.id), RedisCall.recording_url(@call.id), @call.cached_caller_session.caller_id)
      @call.enqueue_call_flow(CallerPusherJob, [@call.cached_caller_session.id, "publish_voter_disconnected"])
      RedisStatus.set_state_changed_time(@call.call_attempt.campaign_id, "Wrap up", @call.cached_caller_session.id)
    end

    render xml: Twilio::TwiML::Response.new{|r| r.Hangup}.text
  end

  # TwiML
  def play_message
    xml = @call.play_message_twiml

    @call.enqueue_call_flow(Providers::Phone::Jobs::DropMessageRecorder, [@call.id, 1])
    @call.enqueue_call_flow(CallerPusherJob, [@call.caller_session.id, 'publish_message_drop_success'])

    render xml: xml
  end

  # Browser
  def submit_result
    @call.wrapup_and_continue(params)
    render nothing: true
  end

  # Browser
  def submit_result_and_stop
    @call.wrapup_and_stop(params)
    render nothing: true
  end

  # Browser
  def hangup
    @call.hungup
    render nothing: true
  end

  # Browser
  def drop_message
    @call.enqueue_call_flow(Providers::Phone::Jobs::DropMessage, [@call.id])

    render nothing: true
  end

  private
  ##
  # Used to initialize @parsed_params to empty Hash for submit_result &
  # submit_result_and_stop.
  # Used to init @parsed_params to populated Hash for Twilio callbacks
  # (:destroy, :incoming, :call_ended, :disconnected)
  #
  def parse_params
    pms = underscore_params
    @parsed_params = Call.column_names.inject({}) do |result, key|
      value = pms[key]
      result[key] = value unless value.blank?
      result
    end
  end

  def underscore_params
    params.inject({}) do |result, k_v|
      k, v = k_v
      result[k.underscore] = v
      result
    end
  end

  def find_call
    if params[:id]
      @call = Call.find(params[:id])
    elsif params['CallSid']
      @call = Call.where(call_sid: params['CallSid']).first
    end
  end

  def find_and_update_answers_and_notes_and_scheduled_date
    find_call
    
    madd = "MissingAnswerDataDebug "

    unless @call.nil?
      madd << "Call[#{@call.id}]"

      @parsed_params["questions"] = params[:question].try(:to_json)
      @parsed_params["notes"] = params[:notes].try(:to_json)

      p "#{madd} parsed_params['questions']#{@parsed_params['questions']}"
      p "#{madd} parsed_params['notes']#{@parsed_params['notes']}"

      RedisCall.set_request_params(@call.id, @parsed_params)
    else
      madd << "Call[NotFound:#{params[:id]}]"
    end

    p "#{madd} params[:question]#{params[:question]}"
    p "#{madd} params[:notes]#{params[:notes]}"
  end

  def find_and_update_call
    find_call
    unless @call.nil?
      RedisCall.set_request_params(@call.id, @parsed_params)
    end
  end
end

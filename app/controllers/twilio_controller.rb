require "twilio"

class TwilioController < ApplicationController
  include ::Twilio
  before_filter :retrieve_call_details

  def callback
    #TWILIO_LOG.info "New Call to : #{@call_attempt.voter.Phone}"
    logger.info "[dialer] call picked up. #{@log_message}; Call Status : #{params['CallStatus']}"
    response = Twilio::Verb.hangup unless params['CallStatus'] == 'in-progress'
    response||= @call_attempt.play_recorded_message if (params[:AnsweredBy] == 'machine')
    response||= @call_attempt.campaign.script.robo_recordings.first.twilio_xml(@call_attempt)
    render :xml => response
  end

  def report_error
    #TWILIO_LOG.info "#{@call_attempt.voter.Phone} : Error occured."
    logger.info "[dialer] error. #{@log_message}"
    @call_attempt.update_attributes(wrapup_time: Time.now)
    render :xml => Twilio::Verb.hangup
  end

  def call_ended
    #TWILIO_LOG.info "#{@call_attempt.voter.Phone} : Call Ended"
    logger.info "[dialer] call ended. #{@log_message}"
    @call_attempt = CallAttempt.find(params[:call_attempt_id])
    voter = @call_attempt.voter
    voter.update_attributes(:result_date => Time.now)
    @call_attempt.update_attributes(wrapup_time: Time.now)
    @call_attempt.capture_answer_as_no_response_for_robo if params['CallStatus'] == "completed"
    render :text => ''
  end

  private
  def retrieve_call_details
    @call_attempt = CallAttempt.find(params[:call_attempt_id])
    @call_attempt.update_attribute('status', CallAttempt::Status::MAP[params['CallStatus']])
    campaign = @call_attempt.campaign
    voter = @call_attempt.voter
    voter.update_attributes(:status => Voter::MAP[params['CallStatus']])
    @log_message = "call_attempt: #{@call_attempt.id} campaign: #{campaign.name}, phone: #{voter.Phone}\n callback parameters: #{params.inspect}"
  end
end

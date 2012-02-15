class CallinController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :preload_models

  def create
    render :xml => Caller.ask_for_pin
  end

  def identify
    @caller = Caller.find_by_pin(params[:Digits])

    if @caller
      unless @caller.account.activated?
          xml =  Twilio::Verb.new do |v|
            v.say "Your account has insufficent funds"
            v.hangup
         end
         render :xml => xml.response
         return
       end

      @session = @caller.caller_sessions.create(:on_call => false, :available_for_call => false, :session_key => generate_session_key, :sid => params[:CallSid], :campaign => @caller.campaign,starttime: Time.now)
      Moderator.caller_connected_to_campaign(@caller, @caller.campaign, @session)
      render :xml => @caller.is_phones_only? ? @caller.ask_instructions_choice(@session) : @session.start
    else
      render :xml => Caller.ask_for_pin(params[:attempt].to_i)
    end
  end

  def hold
    render :template => 'callin/hold.xml.builder', :layout => false
  end

end

class TransferAttempt < ActiveRecord::Base
  belongs_to :transfer
  belongs_to :caller_session
  belongs_to :call_attempt
  include Rails.application.routes.url_helpers
  
  
  
  def conference(caller_session, call_attempt)
    update_attributes(call_start: Time.now)
    Twilio::TwiML::Response.new do |r|
      r.Dial :hangupOnStar => 'false', :action => disconnect_transfer_path(self, :host => Settings.host), :record=>caller_session.campaign.account.record_calls do |d|
        d.Conference session_key, :waitUrl => hold_call_url(:host => Settings.host), :waitMethod => 'GET', :beep => false, :endConferenceOnExit => false
      end
    end.text
  end
  
  def fail
     xml =  Twilio::Verb.new do |v|
       v.say "The transfered call was not answered "
       v.hangup
    end
    xml.response    
  end
  
  def hangup
    Twilio::TwiML::Response.new { |r| r.Hangup }.text
  end
  
  def redirect_callee
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    Twilio::Call.redirect(call_attempt.sid, callee_transfer(:host => Settings.host, :port => Settings.port, session_key: session_key))        
  end
  
  def redirect_caller
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    Twilio::Call.redirect(caller_session.sid, caller_transfer(:host => Settings.host, :port => Settings.port, session_key: session_key))        
  end
  
  
  
end
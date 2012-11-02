require 'resque-loner'
class UpdateTwilioStatsCallerSession
  include Resque::Plugins::UniqueJob
  @queue = :twilio_stats_session
  
  def self.perform
    caller_sessions = []
    twillio_lib = TwilioLib.new
    
    WebuiCallerSession.where("endtime is not NULL and tPrice is NULL and (tStatus is NULL or tStatus = 'completed') ").limit(100).each do |session|
        caller_sessions << twillio_lib.update_twilio_stats_by_model(session)
    end
    WebuiCallerSession.import caller_sessions, :on_duplicate_key_update=>[:tCallSegmentSid, :tAccountSid,
                                        :tCalled, :tCaller, :tPhoneNumberSid, :tStatus, :tStartTime, :tEndTime, :tDuration, :tPrice, :tFlags]    
                                        
                                        
    caller_sessions = []
    twillio_lib = TwilioLib.new

    PhonesOnlyCallerSession.where("endtime is not NULL and tPrice is NULL and (tStatus is NULL or tStatus = 'completed') ").limit(100).each do |session|
      if !session.sid.nil? && session.sid.starts_with?("VX")
        session.tEndTime = session.endtime
        session.tStartTime = session.starttime
        session.tPrice = 0.0
        caller_sessions << session
      else
        caller_sessions << twillio_lib.update_twilio_stats_by_model(session)
      end      
     
    end
    PhonesOnlyCallerSession.import caller_sessions, :on_duplicate_key_update=>[:tCallSegmentSid, :tAccountSid,
                                        :tCalled, :tCaller, :tPhoneNumberSid, :tStatus, :tStartTime, :tEndTime, :tDuration, :tPrice, :tFlags]    
                                        
  end
  
end
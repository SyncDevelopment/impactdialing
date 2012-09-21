require 'em-http-request'

class RedirectCallerJob 
    Resque::Plugins::Timeout.timeout = 10
  @queue = :redirect_caller_job
  
   def self.perform(call_attempt_id)    
     call_attempt = CallAttempt.find(call_attempt_id)
     call_attempt.redirect_caller
     
   end
end
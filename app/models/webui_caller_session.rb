class WebuiCallerSession < CallerSession  
  include Rails.application.routes.url_helpers
  
  call_flow :state, :initial => :initial do    
    
      state :initial do
        event :start_conf, :to => :connected
      end 
      
      state all - [:initial] do
        event :end_conf, :to => :conference_ended
      end
            
      state :connected do                
        before(:always) { start_conference; publish_start_calling }
        after(:success) { enqueue_call_flow(CallerPusherJob, [self.id,  "publish_caller_conference_started"]) }
        event :pause_conf, :to => :paused, :if => :call_not_wrapped_up?
        event :start_conf, :to => :connected
        event :run_ot_of_phone_numbers, :to=> :campaign_out_of_phone_numbers        
        event :stop_calling, :to=> :stopped
      end
      
      state :disconnected do end
      
      
      state :paused do        
        event :start_conf, :to => :account_has_no_funds, :if => :funds_not_available?
        event :start_conf, :to => :time_period_exceeded, :if => :time_period_exceeded?   
        event :start_conf, :to => :connected
        event :stop_calling, :to=> :stopped
      end
      
      state :stopped do
        before(:always) { end_running_call }        
      end
      
      
  end
  
  
  
  def call_not_wrapped_up?  
    attempt_in_progress.try(:connecttime) != nil &&  attempt_in_progress.try(:not_wrapped_up?)  
  end
  
  def publish_sync(event, data)
    Pusher[session_key].trigger(event, data.merge!(:dialer => self.campaign.type))
  end
  

end
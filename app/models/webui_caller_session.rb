class WebuiCallerSession < CallerSession  
  include Rails.application.routes.url_helpers
  
  def start_conf
    return account_not_activated_twiml if account_not_activated?
    return account_has_no_funds_twiml if funds_not_available?
    return subscription_limit_twiml if subscription_limit_exceeded?
    return time_period_exceeded_twiml if time_period_exceeded?
    return caller_on_call_twiml if is_on_call?
    start_conference
    publish_start_calling
    enqueue_call_flow(CallerPusherJob, [self.id,  "publish_caller_conference_started"]) 
    connected_twiml
  end
  
  def continue_conf
    start_conference
    enqueue_call_flow(CallerPusherJob, [self.id,  "publish_caller_conference_started"]) 
    connected_twiml
  end
  
  
  def disonnected
    disonnected_twiml
  end
  
  def pause
    paused_twiml
  end
  
  def stop_calling
    end_running_call
  end
  
  def call_not_wrapped_up?  
    attempt_in_progress.try(:connecttime) != nil &&  attempt_in_progress.try(:not_wrapped_up?)  
  end
  
  def publish_sync(event, data)
    Pusher[session_key].trigger(event, data.merge!(:dialer => self.campaign.type))
  end
  

end
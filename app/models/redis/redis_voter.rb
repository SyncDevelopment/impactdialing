class RedisVoter
  include Redis::Objects
  
  def self.load_voter_info(voter_id, voter)
    voter(voter_id).bulk_set(voter.attributes.to_options)
  end
  
  def self.read(voter_id)
    voter(voter_id).all    
  end
  
  def self.voter(voter_id)
    Redis::HashKey.new("voter:#{voter_id}", $redis_call_flow_connection)    
  end
  
  def self.abandon_call(voter_id)
    voter_hash = voter(voter_id)
    voter_hash.bulk_set({status: CallAttempt::Status::ABANDONED, call_back: false})
    voter_hash.delete('caller_session_id') 
    voter_hash.delete('caller_id') 
  end
  
  def self.failed_call(voter_id)
    voter(voter_id).bulk_set({status: CallAttempt::Status::FAILED})
  end

  def self.end_answered_call(voter_id)
    voter_hash = voter(voter_id)
    voter_hash.store("last_call_attempt_time", Time.now)
    voter_hash.delete('caller_session_id')
  end
  
  def self.answered_by_machine(voter_id, status)
    voter_hash = voter(voter_id)
    voter_hash.store("status", status)
    voter_hash.delete('caller_session_id')
  end
  
  def self.set_status(voter_id, status)
    voter(voter_id).store('status', status)
  end
  
  def self.schedule_for_later(voter_id, scheduled_date)
    voter(voter_id).bulk_set({status: CallAttempt::Status::SCHEDULED, scheduled_date: scheduled_date, call_back: true})
  end
    
  def self.assigned_to_caller?(voter_id)
    voter(voter_id).has_key?("caller_session_id")
  end
  
  def self.assign_to_caller(voter_id, caller_session_id)
    voter(voter_id).store('caller_session_id', caller_session_id) 
  end
  
  def self.caller_session_id(voter_id)
    read(voter_id)['caller_session_id']
  end
  
  
  def self.setup_call(voter_id, call_attempt_id, caller_session_id)
    voter(voter_id).bulk_set({status: CallAttempt::Status::RINGING, last_call_attempt: call_attempt_id, last_call_attempt_time: Time.now, caller_session_id: caller_session_id })
  end
  
  def self.connect_lead_to_caller(voter_id, campaign_id, call_attempt_id)
    if RedisVoter.assigned_to_caller?(voter_id)
      caller_session_id = RedisVoter.read(voter_id)['caller_session_id']   
    else 
      caller_session_id = RedisAvailableCaller.longest_waiting_caller(campaign_id)
      RedisVoter.assign_to_caller(voter_id, caller_session_id) 
      RedisAvailableCaller.remove_caller(campaign_id, caller_session_id)
      RedisCallerSession.set_attempt_in_progress(caller_session_id, call_attempt_id)      
    end
    voter(voter_id).bulk_set({caller_id: RedisCallerSession.read(caller_session_id)["caller_id"], status: CallAttempt::Status::INPROGRESS})
  end
  
  def self.could_not_connect_to_available_caller?(voter_id)
    # check caller disconnected
    !assigned_to_caller?(voter_id) || RedisCallerSession.disconnected?(caller_session_id(voter_id))
  end
  
end
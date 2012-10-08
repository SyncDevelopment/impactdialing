class RedisOnHoldCaller  
  include Redis::Objects
  
  def self.list(campaign_id)
    Redis::SortedSet.new("campaign_id:#{campaign_id}:on_hold_caller", $redis_dialer_connection)
  end
  
  def self.add(campaign_id, caller_session_id)
    list(campaign_id).push(caller_session_id)
  end
  
  def self.longest_waiting_caller(campaign_id)
    list(campaign_id).pop
  end
  
end
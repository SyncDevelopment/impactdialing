require 'redis/list'
class RedisCallFlow
  include Redis::Objects

  def self.current_time
    Time.now.utc.to_s
  end
  
  # done
  def self.push_to_not_answered_call_list(call_id, call_status)   
    $redis_call_end_connection.lpush "not_answered_call_list", {id: call_id, call_status: call_status, current_time: current_time}.to_json
  end
  
  # done
  def self.push_to_abandoned_call_list(call_id)    
    $redis_call_flow_connection.lpush "abandoned_call_list", {id: call_id, current_time: current_time}.to_json
  end
  
  # done
  def self.push_to_processing_by_machine_call_hash(call_id)        
    processing_by_machine_call_hash.store(call_id, current_time) 
  end

  def self.record_message_drop_info(call_id, recording_id, drop_type)
    $redis_call_flow_connection.hset "message_dropped", call_id, {recording_id: recording_id, drop_type: drop_type}.to_json
  end

  def self.get_message_drop_info(call_id)
    info = $redis_call_flow_connection.hget "message_dropped", call_id
    info.nil? ? {} : JSON.parse(info)
  end
  
  # done
  def self.push_to_end_by_machine_call_list(call_id)    
    $redis_call_flow_connection.lpush "end_answered_by_machine_call_list", {id: call_id, current_time: current_time}.to_json
  end
    
  def self.push_to_disconnected_call_list(call_id, recording_duration, recording_url, caller_id)
    payload = {
      id:                 call_id,
      recording_duration: recording_duration,
      recording_url:      recording_url,
      caller_id:          caller_id,
      current_time:       current_time
    }

    $redis_call_flow_connection.lpush "disconnected_call_list", payload.to_json
  end
  
  def self.push_to_wrapped_up_call_list(call_id, caller_type, voter_id)
    if voter_id.blank?
      Rails.logger.error "[PersistCalls:VoterlessCall] RedisCallFlow: Pushing CallID[#{call_id}] CallerType[#{caller_type}] VoterID[#{voter_id}]"
    end

    $redis_call_flow_connection.lpush "wrapped_up_call_list", {id: call_id, caller_type: caller_type, voter_id: voter_id, current_time: current_time}.to_json
  end
  
  def self.not_answered_call_list
    $redis_call_end_connection.lrange "not_answered_call_list", 0, -1
  end
  
  def self.abandoned_call_list
    $redis_call_flow_connection.lrange "abandoned_call_list", 0, -1       
  end
  
  def self.processing_by_machine_call_hash
    Redis::HashKey.new("processing_by_machine_call_list", $redis_call_flow_connection)        
  end
  
  def self.end_answered_by_machine_call_list
    $redis_call_flow_connection.lrange "end_answered_by_machine_call_list", 0, -1     
  end
  
  def self.disconnected_call_list
    $redis_call_flow_connection.lrange "disconnected_call_list", 0, -1
  end
  
  def self.wrapped_up_call_list
    $redis_call_flow_connection.lrange "wrapped_up_call_list", 0, -1
  end
  
  
  
  
  
end

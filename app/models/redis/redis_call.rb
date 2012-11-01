class RedisCall
  
  def self.set_request_params(call_id, options)
    id = "call_flow:#{call_id}"
    data = call_data(call_id) || '{}'
    hash = JSON.parse(data)
    $redis_call_uri_connection.set id, hash.merge(options).to_json
  end
  
  def self.answered_by(call_id)
    data = call_data(call_id)
    hash = JSON.parse(data)
    hash["answered_by"]    
  end
  
  def self.call_status(call_id)
    data = call_data(call_id)
    hash = JSON.parse(data)
    hash["call_status"]    
  end
  
  def self.questions(call_id)
    data = call_data(call_id)
    hash = JSON.parse(data)
    hash["questions"]        
  end

  def self.notes(call_id)
    data = call_data(call_id)
    hash = JSON.parse(data)
    hash["notes"]        
  end

  def self.questions_and_notes(call_id)
    data = call_data(call_id)
    return nil unless data
    JSON.parse(data)
  end
  
  def self.delete(call_id)
    $redis_call_uri_connection.del "call_flow:#{call_id}"
  end

  def self.call_data(call_id)
    $redis_call_uri_connection.get "call_flow:#{call_id}"
  end
  
end

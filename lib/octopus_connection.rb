module OctopusConnection
  extend self
  def connection(shard = :master)
    return ActiveRecord::Base.connection
    # return ActiveRecord::Base.connection unless Octopus.enabled?
    # ActiveRecord::Base.using(shard).connection.select_connection
  end
  
  def dynamic_shard(*shards)
    shards.sample
  end
end

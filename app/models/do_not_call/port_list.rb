module DoNotCall
  class PortList
    attr_reader :namespace

    def self.cache(namespace, file)
      list = new(namespace)
      list.cache(file)
      list
    end

    def redis
      @redis ||= Redis.new
    end

    def delete_all
      redis.del key
    end

    def initialize(namespace)
      @namespace = namespace
    end

    def key
      "do_not_call:ported:#{namespace}"
    end

    def cache(file)
      delete_all
      parser = FileParser.new(file)
      parser.in_batches do |ported_numbers|
        redis.sadd key, ported_numbers
      end
    end

    def exists?(phone)
      redis.sismember(key, phone)
    end

    def all
      redis.smembers(key)
    end
  end
end
##
# Maintains cache of dialed or skipped phone numbers - really any number
# that has had some action taken by a caller or is otherwise
# not available for dialing right away.
#
class CallFlow::DialQueue::RecycleBin
  attr_reader :campaign

  delegate :recycle_rate, to: :campaign

  include CallFlow::DialQueue::Util
  include CallFlow::DialQueue::SortedSetScore

private
  def log(*args)
    CallFlow::DialQueue.log(*args)
  end

  def keys
    {
      bin: "dial_queue:#{campaign.id}:bin"
    }
  end

public
  def initialize(campaign)
    CallFlow::DialQueue.validate_campaign!(campaign)

    @campaign = campaign
  end

  def exists?
    redis.exists keys[:bin]
  end

  def add(household)
    redis.zadd keys[:bin], *memberize(household)

    return (not missing?(household.phone))
  end

  def missing?(phone)
    redis.zscore(keys[:bin], phone).nil?
  end

  def remove(phone)
    redis.zrem keys[:bin], phone
  end

  def remove_all(phones)
    return if phones.blank?
    
    redis.zrem keys[:bin], phones
  end

  def size
    redis.zcard keys[:bin]
  end

  def all
    redis.zrange keys[:bin], 0, -1
  end

  def reuse(&block)
    items = expired
    yield items
    remove_all items.map{|item| item.last}
  end

  def expired
    min   = '-inf'
    max   = "#{campaign.recycle_rate.hours.ago.to_i}.999"
    items = redis.zrangebyscore(keys[:bin], min, max, with_scores: true)

    # redis-rb returns [item, score] but expects [score, item] when pushing
    items.map{|item| item.rotate(1)}
  end

  def dialed(household)
    return false unless household.cache?
    add(household)
  end
end

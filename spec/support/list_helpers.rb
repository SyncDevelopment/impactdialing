class Forgery::Address < Forgery
  def self.clean_phone
    formats[:clean_phone].random.to_numbers
  end
end

module ListHelpers
  def import_list(list, households, household_namespace='active', zset_namespace='active')
    redis = Redis.new
    base_key = "dial_queue:#{list.campaign_id}:households:#{household_namespace}"
    sequence = 1
    lead_sequence = 1
    households.each do |phone, household|
      household['sequence'] = sequence
      leads = []
      household[:leads].each do |lead|
        lead['sequence'] = lead_sequence
        leads << lead
        lead_sequence += 1
      end
      household[:leads] = leads
      key = "#{base_key}:#{phone[0..ENV['REDIS_PHONE_KEY_INDEX_STOP'].to_i]}"
      hkey = phone[ENV['REDIS_PHONE_KEY_INDEX_STOP'].to_i + 1..-1]
      redis.hset key, hkey, household.to_json
      redis.zadd "dial_queue:#{list.campaign_id}:#{zset_namespace}", zscore(sequence), phone 
      sequence += 1
    end
  end

  def add_leads(list, phone, leads, household_namespace='active', zset_namespace='active')
    lead_sequence = 1
    lds = []
    leads.each do |lead|
      lead['sequence'] = lead_sequence
      lead_sequence += 1
      lds << lead
    end
    leads = lds
    redis = Redis.new
    base_key = "dial_queue:#{list.campaign_id}:households:#{household_namespace}"
    key = "#{base_key}:#{phone[0..ENV['REDIS_PHONE_KEY_INDEX_STOP'].to_i]}"
    hkey = phone[ENV['REDIS_PHONE_KEY_INDEX_STOP'].to_i + 1..-1]
    current_household = JSON.parse(redis.hget(key, hkey))
    current_household['leads'] += leads
    redis.hset(key, hkey, current_household.to_json)
  end

  def zscore(sequence)
    Time.now.utc.to_f
  end

  def disable_list(list)
    list.update_attributes!(enabled: false)
  end

  def enable_list(list)
    list.update_attributes!(enabled: true)
  end

  def stub_list_parser(parser_double, redis_key, household)
    allow(parser_double).to receive(:parse_file).and_yield([redis_key], household, 0, {})
    allow(CallList::Imports::Parser).to receive(:new){ parser_double }
  end

  def build_household_hashes(n, list, with_custom_id=false)
    h = {}
    n.times do
      h.merge!(build_household_hash(list, with_custom_id))
    end
    h
  end

  def build_household_hash(list, with_custom_id=false)
    phone = Forgery(:address).clean_phone
    leads = build_leads_array( (1..5).to_a.sample, list, phone, with_custom_id )
    if with_custom_id
      # de-dup
      ids = []
      leads.map! do |lead|
        if ids.include? lead[:custom_id]
          nil
        else
          ids << lead[:custom_id]
          lead
        end
      end.compact!
    end
    {
      phone => {
        leads: leads,
        blocked: 0,
        uuid: "hh-uuid-#{phone}",
        score: Time.now.to_f
      }
    }
  end

  def build_leads_array(n, list, phone, with_custom_id=false)
    a = []
    n.times do |i|
      id = with_custom_id ? i : false
      a << build_lead_hash(list, phone, id)
    end
    a
  end

  def build_lead_hash(list, phone, with_custom_id=false)
    @uuid ||= UUID.new
    h = {
      voter_list_id: list.id.to_s,
      uuid: @uuid.generate,
      phone: phone,
      first_name: Forgery(:name).first_name,
      last_name: Forgery(:name).last_name
    }
    if with_custom_id
      custom_id = with_custom_id.kind_of?(Integer) ? with_custom_id : Forgery(:basic).number
      h.merge!(custom_id: custom_id)
    end
    h
  end
end


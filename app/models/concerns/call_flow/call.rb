module CallFlow
  class CallFlow::BaseArgumentError < ArgumentError; end

  class Call
    class InvalidParams < CallFlow::BaseArgumentError; end
    class InvalidBaseKey < CallFlow::BaseArgumentError; end

    include CallFlow::DialQueue::Util

    attr_reader :account_sid, :sid

  protected
    def self.twiml_params(raw_params)
      CallFlow::TwilioCallParams.load(raw_params)
    end

    def self.save_param_for(read_param)
      write_param = read_param.underscore
      if ['call_status', 'sid'].include?(write_param)
        write_param.gsub!('call_', '')
      end
      write_param
    end

    def self.params_for_create(raw_params)
      save_params = {}
      twiml_params(raw_params).each do |key,value|
        save_params[ save_param_for(key) ] = value
      end
      save_params
    end

    def validate!
      if account_sid.blank? or sid.blank?
        raise CallFlow::Call::InvalidParams, "SIDs for Account and Call are required for CallFlow::Call. They were: AccountSid[#{account_sid}] CallSid[#{sid}]."
      end
    end

  public
    def initialize(account_sid, sid)
      @account_sid = account_sid
      @sid         = sid
      validate!
    end

    def self.create(raw_params)
      p ".create called w/ #{raw_params}"
      account_sid = (raw_params['AccountSid'] || raw_params['account_sid'])
      sid         = (raw_params['CallSid'] || raw_params['sid'])
      storage     = CallFlow::Call::Storage.new(account_sid, sid, namespace)

      storage.save(params_for_create(raw_params))
      self.new(account_sid, sid)
    end

    def storage
      @storage ||= CallFlow::Call::Storage.new(account_sid, sid)
    end

    def state
      @state ||= CallFlow::Call::State.new(storage.key)
    end

    def update_history(_state)
      state.visited(_state)
    end

    def state_visited?(_state)
      state.visited?(_state)
    end

    def state_missed?(_state)
      state.not_visited?(_state)
    end
  end
end


ImpactDialing::Application.configure do
  TWILIO_ACCOUNT="AC422d17e57a30598f8120ee67feae29cd"
  TWILIO_AUTH="897298ab9f34357f651895a7011e1631"
  TWILIO_APP_SID="AP9bdd1111d0b34e3c9c3835d2253aa693"
  APP_NUMBER="4157020991"
  HOST = APP_HOST = "admin.impactdialing.com"
  PORT = 80
  TEST_CALLER_NUMBER="8583679749"
  TEST_VOTER_NUMBER="4154486970"
  PUSHER_APP_ID="6964"
  PUSHER_KEY="6f37f3288a3762e60f94"
  PUSHER_SECRET="b9a1cfc2c1ab4b64ad03"
  MONITOR_TWILIO_APP_SID="APe95d3960a26f46e69697b6840149655b"
  TWILIO_ERROR = "http://status-impactdialing.heroku.com/twilio/error_production"
  HOLD_MUSIC_URL = "https://s3.amazonaws.com/hold_music/impactdialing_holdmusic_v1.mp3"

  # Settings specified here will take precedence over those in config/environment.rb

  # The production environment is meant for finished, "live" apps.
  # Code is not reloaded between requests
  config.cache_classes = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local = false
  config.action_controller.perform_caching             = true

  # See everything in the log (default is :info)
  config.log_level = :debug

  config.active_support.deprecation = :log

  config.after_initialize do
    #  ActiveMerchant::Billing::Base.mode = :test
    ActiveMerchant::Billing::LinkpointGateway.pem_file  = File.read(Rails.root.join('1383715.pem'))
    ::BILLING_GW = gateway = ActiveMerchant::Billing::LinkpointGateway.new(
      :login => "1383715"
    )
  end

  # Use a different logger for distributed setups
  # config.logger = SyslogLogger.new

  # Use a different cache store in production
  # config.cache_store = :mem_cache_store

  # Enable serving of images, stylesheets, and javascripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # Disable delivery errors, bad email addresses will be ignored
  # config.action_mailer.raise_delivery_errors = false

  # Enable threaded mode
  # config.threadsafe!


  # memcache_options = {
  #   :c_threshold => 10000,
  #   :compression => true,
  #   :debug => false,
  #   :namespace => 'some_ns',
  #   :readonly => false,
  #   :urlencode => false
  # }
  #
  # CACHE = MemCache.new memcache_options
  # #CACHE.servers = '127.0.0.1:11211'
  # CACHE.servers = 'domU-12-31-39-10-89-26.compute-1.internal:11211'
  #
  # begin
  #    PhusionPassenger.on_event(:starting_worker_process) do |forked|
  #      if forked
  #        # We're in smart spawning mode, so...
  #        # Close duplicated memcached connections - they will open themselves
  #        CACHE.reset
  #      end
  #    end
  # # In case you're not running under Passenger (i.e. devmode with mongrel)
  # rescue NameError => error
  # end
end
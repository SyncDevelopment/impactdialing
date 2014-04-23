require File.expand_path('../boot', __FILE__)

require "rails/all"

# If you have a Gemfile, require the gems listed there, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env) if defined?(Bundler)

FROM_EMAIL_NAME  = 'Michael Kaiser-Nyman, Impact Dialing'
FROM_EMAIL       = "email@impactdialing.com"
MICHAEL_EMAIL    = "michael@impactdialing.com"
EXCEPTIONS_EMAIL = "exceptions@impactdialing.com"
TECH_EMAIL       = "jeremiah@impactdialing.com"
SALES_EMAIL      = "joseph@impactdialing.com"
SUPPORT_EMAIL    = "support@impactdialing.com"

module ImpactDialing
  class Application < Rails::Application
  #  config.time_zone = "Pacific Time (US & Canada)"
    #config.active_record.default_timezone = :local


    if ["heroku", "heroku_staging"].include?(Rails.env)
      config.logger = Logger.new(STDOUT)
      config.logger.level = Logger.const_get(ENV['LOG_LEVEL'] ?  ENV['LOG_LEVEL'].upcase : 'INFO')
    end
    config.filter_parameters << :password << :card_number << :card_verification << :cc << :code
    # config.time_zone = 'UTC'

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Add additional load paths for your own custom dirs
    config.autoload_paths += %W(#{config.root}/jobs)
    config.autoload_paths += %W(#{config.root}/app/concerns)
    config.autoload_paths += %W(#{config.root}/app/models/redis)

    # Specify gems that this application depends on and have them installed with rake gems:install
    # config.gem "bj"
    # config.gem "hpricot", :version => '0.6', :source => "http://code.whytheluckystiff.net"
    # config.gem "sqlite3-ruby", :lib => "sqlite3"
    # config.gem "aws-s3", :lib => "aws/s3"

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Skip frameworks you're not going to use. To use Rails without a database,
    # you must remove the Active Record framework.
    # config.frameworks -= [ :active_record, :active_resource, :action_mailer ]

    # Activate observers that should always be running
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names.

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}')]
    config.i18n.default_locale = :en
    config.i18n.fallbacks = [:en]
    config.action_view.javascript_expansions[:jdefaults] = %w(jquery jquery-ui jquery_ujs application)
    config.action_view.javascript_expansions[:caller_ui] = [
      'jquery.form.js', 'flash_detect_min.js', 'browser_detect.js',
      'date.js', 'underscore-min', 'mustache', 'backbone',
      'impactdialing', 'models/campaign_call.js',
      'utilities/debugger', 'utilities/period_stats',
      'services/network_connection_monitor', 'services/pusher_connection_monitor',
      'services/twilio_connection_monitor',
      'services/pusher', 'services/twilio',
      'views/campaign_call.js', 'models/caller_script.js',
      'models/lead_info.js', 'views/lead_info.js',
      'views/schedule_callback.js', 'models/caller_session.js',
      'views/caller_script.js', 'views/start_calling.js',
      'views/caller_actions.js', 'jquery.stickyscroll.js'
    ]

    GC::Profiler.enable
  end
end

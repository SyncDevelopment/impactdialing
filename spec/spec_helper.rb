# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RACK_QUEUE_METRICS_INTERVAL'] = "#{(3600 * 24)}"
ENV["RAILS_ENV"] ||= 'test'
if ENV['RAILS_ENV'] == 'development'
  ENV['RAILS_ENV'] = 'test'
end
ENV['REDIS_URL'] ||= 'redis://localhost:6379'
ENV['TWILIO_CALLBACK_HOST'] ||= 'test.com'
ENV['CALL_END_CALLBACK_HOST'] ||= 'test.com'
ENV['INCOMING_CALLBACK_HOST'] ||= 'test.com'
ENV['VOIP_API_URL'] ||= 'test.com'
ENV['TWILIO_CALLBACK_PORT'] ||= '80'
ENV['RECORDING_ENV'] = 'test'
ENV['CALLIN_PHONE'] ||= '5555551234'

# require 'rubygems'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'webmock/rspec'
require 'impact_platform'
require 'paperclip/matchers'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

Capybara.javascript_driver = :selenium

VCR.configure do |c|
  # c.debug_logger = File.open(Rails.root.join('log', 'vcr-debug.log'), 'w')
  if ENV['RAILS_ENV'] == 'e2e'
    c.allow_http_connections_when_no_cassette = true
  else
    c.cassette_library_dir = Rails.root.join 'spec/fixtures/vcr_cassettes'
    c.hook_into :webmock
  end
end

RSpec.configure do |config|
  config.infer_spec_type_from_file_location!
  config.profile_examples = 10
  config.include FactoryGirl::Syntax::Methods
  config.include TwilioRequestStubs
  config.include FactoryGirlImportHelpers
  config.include Paperclip::Shoulda::Matchers

  config.mock_with :rspec

  config.before(:suite) do
    WebMock.allow_net_connect!

    if ENV['RAILS_ENV'] == 'e2e'
      DatabaseCleaner.strategy = :truncation
    else
      DatabaseCleaner.strategy = :transaction
    end
    DatabaseCleaner.clean_with :truncation

    module ImpactPlatform::Heroku::UploadDownloadHooks
      alias_method :real_after_enqueue_scale_up, :after_enqueue_scale_up

      def after_enqueue_scale_up(*args); end
    end
  end

  config.after(:suite) do
    DatabaseCleaner.clean

    module ImpactPlatform::Heroku::UploadDownloadHooks
      alias_method :after_enqueue_scale_up, :real_after_enqueue_scale_up
    end
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  if ENV['RAILS_ENV'] == 'e2e'
    config.use_transactional_fixtures = false
  else
    config.use_transactional_fixtures = true
  end

  config.fixture_path = Rails.root.join('spec/fixtures')
end

include ActionDispatch::TestProcess

def resque_jobs(queue)
  Resque.peek(queue, 0, 100)
end

def login_as(user)
  allow(@controller).to receive(:current_user).and_return(user)
  session[:user] = user.id
  session[:caller] = user.id
end

def http_login
  name = AdminController::USER_NAME
  password = AdminController::PASSWORD
  if page.driver.respond_to?(:basic_auth)
    page.driver.basic_auth(name, password)
  elsif page.driver.respond_to?(:basic_authorize)
    page.driver.basic_authorize(name, password)
  elsif page.driver.respond_to?(:browser) && page.driver.browser.respond_to?(:basic_authorize)
    page.driver.browser.basic_authorize(name, password)
  else
    raise "I don't know how to log in!"
  end
end

def create_user_and_login
  user = build :user
  visit '/client/login'
  fill_in 'Email address', :with => user.email
  fill_in 'Pick a password', :with => user.new_password
  click_button 'Sign up'
  click_button 'I and the company or organization I represent accept these terms.'
end

def web_login_as(user)
  visit '/client/login'
  fill_in 'Email', with: user.email
  fill_in 'Password', with: 'password'
  click_on 'Log in'
end

def caller_login_as(caller)
  visit '/caller/login'
  fill_in 'Username', with: caller.username
  fill_in 'Password', with: caller.password
  click_on 'Log in'
end

def fixture_path
  Rails.root.join('spec/fixtures/').to_s
end

def fixture_file_upload(path, mime_type = nil, binary = false)
  Rack::Test::UploadedFile.new("#{fixture_path}#{path}", mime_type, binary)
end
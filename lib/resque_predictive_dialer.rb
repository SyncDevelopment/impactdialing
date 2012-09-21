RAILS_ROOT = File.expand_path('../..', __FILE__)
require File.join(RAILS_ROOT, 'config/environment')
DIALER_ROOT = ENV['DIALER_ROOT'] || File.expand_path('..', __FILE__)
FileUtils.mkdir_p(File.join(DIALER_ROOT, 'log'), :verbose => true)
ActiveRecord::Base.logger = Logger.new(File.open(File.join(DIALER_ROOT, 'log', "dialer_#{ENV['RAILS_ENV']}.log"), 'a'))
require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"



loop do
  begin
<<<<<<< HEAD
    logged_in_campaigns = RedisCampaign.running_campaigns
    logged_in_campaigns.each do |campaign_id|
      campaign = Campaign.find(campaign_id)
      campaign.dial_resque if !campaign.calculate_dialing?
=======
    logged_in_campaigns = CallerSession.campaigns_on_call
    logged_in_campaigns.each do |c|
      campaign = Campaign.find(c.campaign_id)
      if campaign.type == Campaign::Type::PREDICTIVE  && !campaign.calculate_dialing? && Predictive.do_not_call_in_production?(campaign.id)
        campaign.dial_resque
      end
>>>>>>> em
    end
  rescue Exception => e
    if e.class==SystemExit
      puts "============ EXITING  ============"
      exit 
    end
    puts "DIALER EXCEPTION Rescued - #{ e } (#{ e.class })!"
    puts "DIALER EXCEPTION Backtrace : #{e.backtrace}"
  end
end
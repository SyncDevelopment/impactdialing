require 'resque-loner'
require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"
require 'librato_resque'

##
# Pull down call data for +CallAttempt+ records from Twilio for billing purposes.
#
# ### Metrics
#
# - completed
# - failed
# - timing
#
# ### Monitoring
#
# Alert conditions:
#
# - failed
# - stops reporting for 5 minutes
#
class UpdateStatsAttemptsEm
  include Resque::Plugins::UniqueJob
  extend LibratoResque

  @queue = :twilio_stats

  def self.perform
    ActiveRecord::Base.clear_active_connections!
    results = []
    stats = []
    twillio_lib = TwilioLib.new
    call_attempts = CallAttempt.where("status in (?) and tPrice is NULL and (tStatus is NULL or tStatus = 'completed') and sid is not null ", ['Message delivered', 'Call completed with success.', 'Call abandoned', 'Hangup or answering machine']).limit(10000)

    twilio_call_attempts = call_attempts.select {|call_attempt| call_attempt.sid.starts_with?("CA")}
    EM.synchrony do
      concurrency = 1000
      # todo: update UpdateStatsAttemptsEm ? concurrency = 50 # twilio rest api concurrency limit per account is ~130
      EM::Synchrony::Iterator.new(twilio_call_attempts, concurrency).map do |attempt, iter|
        http = twillio_lib.update_twilio_stats_by_model_em(attempt)
        http.callback {
          twillio_lib.twilio_xml_parse(http.response, attempt)
          results << attempt.attributes
          iter.return(http)
        }
        http.errback { iter.return(http) }
      end
      CallAttempt.import_hashes(results)
      EventMachine.stop
    end
  end
end
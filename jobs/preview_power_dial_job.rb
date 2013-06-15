class PreviewPowerDialJob
  include Sidekiq::Worker
  sidekiq_options :retry => false
  sidekiq_options :failures => true

  def perform(caller_session_id, voter_id)
    caller_session = CallerSession.find_by_id_cached(caller_session_id)
    if caller_session.funds_not_available?
      caller_session.redirect_account_has_no_funds
      return
    end
    puts caller_session.time_period_exceeded?
    if caller_session.time_period_exceeded?
      caller_session.redirect_caller_time_period_exceeded
      return
    end

    voter = Voter.find(voter_id)
    begin
      Twillio.dial(voter, caller_session)
    rescue ActiveRecord::StaleObjectError
      caller_session.redirect_caller
    end
  end
end
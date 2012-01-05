class VoterObserver < ActiveRecord::Observer

  def answer_recorded(voter)
    DIALER_LOGGER.info "ObSeRvER====================================================="
    return unless voter.unanswered_questions.blank?
    return unless voter.answer_recorded_by

    voter.current_call_attempt.try(:update_attributes, {:wrapup_time => Time.now})
    DIALER_LOGGER.info "====================================================="
    if voter.campaign.predictive_type == Campaign::Type::PREVIEW || voter.campaign.predictive_type == Campaign::Type::PROGRESSIVE
      next_voter = voter.campaign.next_voter_in_dial_queue(voter.id)
      voter.answer_recorded_by.publish("voter_push", next_voter ? next_voter.info : {})
    else
      voter.answer_recorded_by.publish("predictive_successful_voter_response", {})
    end
    voter.answer_recorded_by.update_attribute(:voter_in_progress, nil)
  end
end

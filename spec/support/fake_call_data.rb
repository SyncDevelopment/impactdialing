module FakeCallData
  def add_voters(campaign, n=25)
    account = campaign.account

    build_and_import_list(:bare_voter, n, {
      account: account,
      campaign: campaign
    })
  end

  def add_callers(campaign, n=5)
    account = campaign.account

    build_and_import_list(:caller, n, {
      account: account,
      campaign: campaign
    })
  end

  def attach_call_attempt(type, voter)
    campaign = voter.campaign

    call_attempt = create(type, {
      campaign: campaign,
      dialer_mode: campaign.type,
      voter: voter
    })

    voter.update_attributes({
      last_call_attempt_id: call_attempt.id,
      last_call_attempt_time: call_attempt.created_at,
      status: call_attempt.status
    })

    call_attempt
  end

  def add_call_attempts(campaign, n=35)
    if campaign.all_voters.empty?
      voters = add_voters(campaign)
    else
      voters = campaign.all_voters
    end

    if campaign.callers.empty?
      callers = add_callers(campaign)
    else
      callers = campaign.callers
    end

    call_attempts = build_and_import_list(:bare_call_attempt, n, {
      campaign: campaign,
      caller: callers.sample,
      voter: voters.sample
    })

    [voters, callers, call_attempts]
  end

  def create_campaign_with_script(type, account)
    # Setup script, questions and possible responses
    script = create(:bare_script, {
      account: account
    })

    questions = build_and_import_list(:bare_question, 4, {
      script: script
    })

    build_and_import_list_for_each(questions, :bare_possible_response, 4) do |question|
      {
        question: question
      }
    end

    campaign = create(type, {
      account: account,
      script: script
    })

    [script, questions, campaign]
  end

  def create_campaign_with_answers(type, account, answer_count=12)
    script, questions, campaign    = create_campaign_with_script(type, account)
    voters, callers, call_attempts = add_call_attempts(campaign)

    build_and_import_sampled_list(:bare_answer, answer_count) do
      sampled_question = questions.sample
      sampled_call_attempt = call_attempts.sample

      {
        voter: sampled_call_attempt.voter,
        caller: sampled_call_attempt.caller,
        question: sampled_question,
        possible_response: sampled_question.possible_responses.sample,
        call_attempt: sampled_call_attempt,
        campaign: campaign
      }
    end

    {
      campaign: campaign,
      call_attempts: call_attempts
    }
  end

  def create_campaign_with_transfer_attempts(type, account)
    res           = create_campaign_with_answers(type, account)
    campaign      = res[:campaign]
    call_attempts = res[:call_attempts]

    transfers = build_and_import_list(:bare_transfer, 3, {
      script: campaign.script
    })

    build_and_import_sampled_list(:bare_transfer_attempt, 12) do
      sampled_transfer     = transfers.sample
      sampled_call_attempt = call_attempts.sample

      {
        campaign: campaign,
        transfer: sampled_transfer,
        call_attempt: sampled_call_attempt
      }
    end

    {
      campaign: campaign
    }
  end
end
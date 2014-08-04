require "spec_helper"


describe Power, :type => :model do

  describe "next voter to be dialed" do

    it "returns priority  not called voter first" do
      campaign = create(:power)
      caller_session = create(:caller_session)
      voter = create(:voter, :status => 'not called', :campaign => campaign)
      priority_voter = create(:voter, :status => 'not called', :campaign => campaign, priority: "1")
      expect(campaign.next_voter_in_dial_queue(nil)).to eq(priority_voter)
    end

    it "returns uncalled voter before called voter" do
      campaign = create(:power)
      caller_session = create(:caller_session)
      create(:voter, :status => CallAttempt::Status::SUCCESS, :last_call_attempt_time => 2.hours.ago, :campaign => campaign)
      uncalled_voter = create(:voter, :status => Voter::Status::NOTCALLED, :campaign => campaign)
      expect(campaign.next_voter_in_dial_queue(nil)).to eq(uncalled_voter)
    end

    it "returns any scheduled voter within a ten minute window before an uncalled voter" do
      campaign = create(:power)
      caller_session = create(:caller_session)
      scheduled_voter = create(:voter, :status => CallAttempt::Status::SCHEDULED, :last_call_attempt_time => 2.hours.ago, :scheduled_date => 1.minute.from_now, :campaign => campaign)
      create(:voter, :status => Voter::Status::NOTCALLED, :campaign => campaign)
      expect(campaign.next_voter_in_dial_queue(nil)).to eq(scheduled_voter)
    end

    it "returns next voter in list if scheduled voter is more than 10 minutes away from call" do
      campaign = create(:power)
      caller_session = create(:caller_session)
      scheduled_voter = create(:voter, :status => CallAttempt::Status::SCHEDULED, :last_call_attempt_time => 2.hours.ago, :scheduled_date => 20.minute.from_now, :campaign => campaign)
      current_voter = create(:voter, :status => Voter::Status::NOTCALLED, :campaign => campaign)
      next_voter = create(:voter, :status => Voter::Status::NOTCALLED, :campaign => campaign)
      expect(campaign.next_voter_in_dial_queue(current_voter.id)).to eq(next_voter)
    end


    it "returns voter with respect to a current voter" do
      campaign = create(:power)
      caller_session = create(:caller_session)
      uncalled_voter = create(:voter, :status => Voter::Status::NOTCALLED, :campaign => campaign)
      current_voter = create(:voter, :status => Voter::Status::NOTCALLED, :campaign => campaign)
      next_voter = create(:voter, :status => Voter::Status::NOTCALLED, :campaign => campaign)
      expect(campaign.next_voter_in_dial_queue(current_voter.id)).to eq(next_voter)
    end

    it "returns no number if only voter to be called a retry and last called time is within campaign recycle rate" do
      time_now = Time.now.utc
      allow(Time).to receive(:now).and_return(time_now)
      campaign = create(:power, recycle_rate: 2)
      caller_session = create(:caller_session)
      scheduled_voter = create(:voter, :first_name => 'scheduled voter', :status => CallAttempt::Status::SCHEDULED, :last_call_attempt_time => 2.hours.ago, :scheduled_date => 20.minutes.from_now, :campaign => campaign)
      retry_voter = create(:voter, :status => CallAttempt::Status::VOICEMAIL, last_call_attempt_time: 1.hours.ago, :campaign => campaign)
      current_voter = create(:voter, :status => CallAttempt::Status::SUCCESS, :campaign => campaign)
      expect(campaign.next_voter_in_dial_queue(current_voter.id)).to be_nil
    end

    it 'does not return any voter w/ a phone number in the blocked number list' do
      blocked = ['1234567890', '0987654321']
      account = create(:account)
      campaign = create(:power, {account: account})
      allow(account).to receive_message_chain(:blocked_numbers, :for_campaign, :pluck){ blocked }
      voter = create(:voter, :status => 'not called', :campaign => campaign, phone: blocked.first)
      priority_voter = create(:voter, :status => 'not called', :campaign => campaign, priority: "1", phone: blocked.second)
      caller_session = create(:caller_session)
      expect(campaign.next_voter_in_dial_queue(nil)).to be_nil
    end

    it 'never returns the current voter when that voter has been skipped' do
      campaign = create(:preview)
      vopt = {
        campaign: campaign
      }
      vone = create(:voter, vopt)
      vtwo = create(:voter, vopt)
      vthr = create(:voter, vopt)

      expect(campaign.next_voter_in_dial_queue(nil)).to eq vone

      vone.reload.skip

      next_voter = campaign.next_voter_in_dial_queue(vone.id)
      expect(next_voter).not_to eq vone
      expect(next_voter).to eq vtwo

      vtwo.reload.skip

      next_voter = campaign.next_voter_in_dial_queue(vtwo.id)
      expect(next_voter).not_to eq vtwo
      expect(next_voter).to eq vthr
    end
  end
end

# ## Schema Information
#
# Table name: `campaigns`
#
# ### Columns
#
# Name                                      | Type               | Attributes
# ----------------------------------------- | ------------------ | ---------------------------
# **`id`**                                  | `integer`          | `not null, primary key`
# **`campaign_id`**                         | `string(255)`      |
# **`name`**                                | `string(255)`      |
# **`account_id`**                          | `integer`          |
# **`script_id`**                           | `integer`          |
# **`active`**                              | `boolean`          | `default(TRUE)`
# **`created_at`**                          | `datetime`         |
# **`updated_at`**                          | `datetime`         |
# **`caller_id`**                           | `string(255)`      |
# **`type`**                                | `string(255)`      |
# **`recording_id`**                        | `integer`          |
# **`use_recordings`**                      | `boolean`          | `default(FALSE)`
# **`calls_in_progress`**                   | `boolean`          | `default(FALSE)`
# **`recycle_rate`**                        | `integer`          | `default(1)`
# **`answering_machine_detect`**            | `boolean`          |
# **`start_time`**                          | `time`             |
# **`end_time`**                            | `time`             |
# **`time_zone`**                           | `string(255)`      |
# **`acceptable_abandon_rate`**             | `float`            |
# **`call_back_after_voicemail_delivery`**  | `boolean`          | `default(FALSE)`
# **`caller_can_drop_message_manually`**    | `boolean`          | `default(FALSE)`
#

require 'spec_helper'
require 'app_health/monitor/recycle_rate_violations'

describe AppHealth::Monitor::RecycleRateViolations do
  def create_attempts(voter, time_a, time_b=Time.now)
    create(:bare_call_attempt, :machine_answered, voter: voter, created_at: time_a, campaign: campaign)
    create(:bare_call_attempt, :machine_answered, voter: voter, created_at: time_b, campaign: campaign) # created_at => Time.now by def
  end

  describe '.ok?' do
    it 'returns true if no call attempts with the same voter id have been created within an hour of each other' do
      expect( subject.ok? ).to be_truthy
    end

    describe 'alarm cases' do
      let(:account){ create(:account) }
      let(:campaign){ create(:power, account: account) }
      let(:voter){ create(:realistic_voter, account: account, campaign: campaign) }

      it '1st attempt 59 min ago; 2nd attempt just now' do
        create_attempts(voter, 59.minutes.ago)

        expect( subject.ok? ).to be_falsy
      end

      it '1st attempt 42 min ago; 2nd attempt 4 min ago' do
        create_attempts(voter, 42.minutes.ago, 4.minutes.ago)

        expect( subject.ok? ).to be_falsy
      end

      it '1st attempt 21 min ago; 2nd attempt 19 min ago' do
        create_attempts(voter, 21.minutes.ago, 19.minutes.ago)

        expect( subject.ok? ).to be_falsy
      end

      it '1st attempt 3 min ago; 2nd attempt now' do
        create_attempts(voter, 3.minutes.ago)

        expect( subject.ok? ).to be_falsy
      end
    end
  end
end

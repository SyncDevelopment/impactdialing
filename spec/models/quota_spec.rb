require 'spec_helper'

describe Quota do

  def prorated_minutes(provider_object, minutes_per_caller)
    total          = provider_object.current_period_end - provider_object.current_period_start
    left           = provider_object.current_period_end - Time.now
    perc           = ((left/total) * 100).to_i / 100.0
    (minutes_per_caller * perc).to_i
  end

  describe '#minutes_available?' do
    let(:quota) do
      Quota.new({
        minutes_allowed: 10
      })
    end
    context 'minutes_allowed - minutes_used - minutes_pending > 0' do
      it 'returns true' do
        quota.minutes_used = 4
        quota.minutes_pending = 0
        quota.minutes_available?.should be_true

        quota.minutes_used = 0
        quota.minutes_pending = 4
        quota.minutes_available?.should be_true
      end
    end

    context 'minutes_allowed - minutes_used - minutes_pending <= 0' do
      it 'returns false' do
        quota.minutes_used = 4
        quota.minutes_pending = 6
        quota.minutes_available?.should be_false

        quota.minutes_pending = 0
        quota.minutes_used = 10
        quota.minutes_available?.should be_false

        quota.minutes_pending = 10
        quota.minutes_used = 0
        quota.minutes_available?.should be_false
      end
    end
  end

  describe '#_minutes_available' do
    let(:quota) do
      Quota.new({
        minutes_allowed: 50
      })
    end

    it 'returns an Integer number of minutes available, calculated as (minutes_allowed - minutes_used - minutes_pending)' do
      quota._minutes_available.should eq quota.minutes_allowed

      quota.minutes_used = 10
      quota._minutes_available.should eq quota.minutes_allowed - 10

      quota.minutes_used = 39
      quota._minutes_available.should eq quota.minutes_allowed - 39

      quota.minutes_pending = 10
      quota._minutes_available.should eq quota.minutes_allowed - 39 - 10
    end

    it 'never returns an Integer < 0' do
      quota.minutes_used = quota.minutes_allowed
      quota.minutes_pending = 12
      quota._minutes_available.should eq 0
    end
  end

  describe '#debit(minutes_to_charge)' do
    let(:account) do
      create(:account)
    end
    let(:quota) do
      account.quota
    end

    it 'returns true on success' do
      quota.debit(5).should be_true
    end

    it 'returns false on failure' do
      quota.account_id = nil # make it invalid
      quota.debit(5).should be_false
    end

    context 'minutes_available >= minutes_to_charge' do
      let(:minutes_to_charge){ 300 }
      before do
        quota.update_attributes!(minutes_allowed: 500)
        quota.debit(minutes_to_charge)
      end
      it 'adds minutes_to_charge to minutes_used' do
        quota._minutes_available.should eq(quota.minutes_allowed - 300)
      end
      it 'leaves minutes_pending unchanged' do
        quota.minutes_pending.should eq(quota.minutes_pending)
      end
    end

    context 'minutes_available < minutes_to_charge' do
      let(:minutes_to_charge){ 7 }
      let(:minutes_used){ 498 }
      let(:minutes_allowed){ 500 }
      let(:expected_minutes_pending) do
        minutes_to_charge - (minutes_allowed - minutes_used)
      end
      before do
        quota.update_attributes!({
          minutes_allowed: minutes_allowed,
          minutes_used: minutes_used
        })
        quota.debit(minutes_to_charge)
      end

      it 'adds (minutes_to_charge - minutes_available) to minutes_used' do
        quota.minutes_used.should eq minutes_allowed
      end

      it 'adds any remaining minutes to minutes_pending' do
        quota.minutes_pending.should eq expected_minutes_pending

        quota.debit(7)
        quota.minutes_pending.should eq expected_minutes_pending + minutes_to_charge

        quota.debit(7)
        quota.minutes_pending.should eq expected_minutes_pending + (minutes_to_charge * 2)
      end
    end
  end

  describe '#prorated_minutes' do
    let(:account) do
      create(:account)
    end
    let(:quota) do
      account.quota
    end
    let(:basic_plan) do
      double('Billing::Plan', {
        id: 'basic',
        minutes_per_quantity: 1000,
        price_per_quantity: 49.0
      })
    end
    let(:provider_object) do
      double('ProviderSubscription', {
        quantity: 1,
        amount: 49.0,
        current_period_start: 2.weeks.ago,
        current_period_end: 2.weeks.from_now
      })
    end
    it 'returns computed minutes based on std prorate formula' do
      quantity = 1
      actual = quota.prorated_minutes(basic_plan, provider_object, quantity)
      expected = 1000 / 2
      actual.should be_within(10).of(expected)
    end
  end

  context 'changing plan features / options' do
    let(:account) do
      create(:account)
    end
    let(:quota) do
      account.quota
    end
    let(:basic_plan) do
      double('Billing::Plan', {
        id: 'basic',
        minutes_per_quantity: 1000,
        price_per_quantity: 49.0
      })
    end
    let(:provider_object) do
      double('ProviderSubscription', {
        quantity: 1,
        amount: 49.0,
        current_period_start: Time.now,
        current_period_end: 1.month.from_now
      })
    end

    describe '#change_plans_or_callers(plan, provider_object, opts)' do
      let(:opts) do
        {
          callers_allowed: 1,
          old_plan_id: 'trial'
        }
      end
      context 'Trial -> Basic' do
        before do
          quota.update_attribute(:minutes_used, 45)
          quota.reload
          quota.minutes_allowed.should eq 50
          quota.callers_allowed.should eq 5
          quota.change_plans_or_callers(basic_plan, provider_object, opts)
        end
        it 'sets callers_allowed to provider_object.quantity' do
          quota.callers_allowed.should eq 1
        end
        it 'sets minutes_allowed to the product of plan.minutes_per_quantity and quantity' do
          quota.minutes_allowed.should eq 1000
        end
        it 'sets minutes_used to zero' do
          quota.minutes_used.should eq 0
        end
      end
      context 'Pro -> Basic +1 caller (21 days into billing cycle)' do
        # This action is a no-op because we don't prorate the change
        # and the customer already paid for usage through the end of
        # the current billing cycle. Stripe will notify when downgraded
        # subscription renews.
        let(:used){ 1250 }
        let(:allowed){ 2500 }
        let(:callers){ 1 }
        before do
          provider_object.stub(:quantity){ 2 }
          quota.update_attributes!({
            minutes_used: used,
            minutes_allowed: allowed,
            callers_allowed: 1
          })
          quota.reload
          opts.merge!({
            old_plan_id: 'pro'
          })
          quota.change_plans_or_callers(basic_plan, provider_object, opts)
        end
        it 'sets callers_allowed to provider_object.quantity' do
          quota.callers_allowed.should eq provider_object.quantity
        end
        it 'does not touch minutes_allowed' do
          quota.minutes_allowed.should eq allowed
        end
        it 'does not touch minutes_used' do
          quota.minutes_used.should eq used
        end
      end
      context 'Basic -> Basic' do
        let(:account) do
          create(:account)
        end
        let(:quota) do
          account.quota
        end
        let(:used){ 750 }
        let(:allowed){ 1000 }
        let(:available){ 250 }
        let(:callers){ 1 }
        before do
          provider_object.stub(:current_period_start){ 7.days.ago }
          provider_object.stub(:current_period_end){ 21.days.from_now }
          quota.update_attributes!({
            minutes_used: used,
            minutes_allowed: allowed,
            minutes_pending: 0,
            callers_allowed: 1
          })
          quota.reload
          opts.merge!({
            old_plan_id: 'basic'
          })
          quota.change_plans_or_callers(basic_plan, provider_object, opts)
        end
        it 'sets callers_allowed to provider_object.quantity' do
          quota.callers_allowed.should eq provider_object.quantity
        end
        context '+1 caller' do
          before do
            provider_object.stub(:quantity){ 2 }
            quota.change_plans_or_callers(basic_plan, provider_object, opts)
          end
          it 'sets minutes_allowed to prorated number of minutes based on billing cycle' do
            minutes_to_add           = prorated_minutes(provider_object, 1000)
            expected_minutes_allowed = minutes_to_add + allowed
            quota.minutes_allowed.should be_within(10).of(expected_minutes_allowed)
          end
          it 'sets callers_allowed to provider_object.quantity' do
            quota.callers_allowed.should eq provider_object.quantity
          end
        end
        context 'removing callers - verify this only changes callers_allowed because this action is not prorated. Minute quotas are updated via stripe event and so' do
          let(:used){ 1250 }
          let(:allowed){ 3000 }
          let(:callers){ 3 }
          before do
            provider_object.stub(:quantity){ 1 }
            quota.update_attributes!({
              minutes_used: used,
              minutes_allowed: allowed,
              callers_allowed: 3
            })
            quota.reload
            opts.merge!({
              old_plan_id: 'basic'
            })
            quota.change_plans_or_callers(basic_plan, provider_object, opts)
          end
          it 'sets callers_allowed to provider_object.quantity' do
            quota.callers_allowed.should eq provider_object.quantity
          end
          it 'does not touch minutes_allowed' do
            quota.minutes_allowed.should eq allowed
          end
          it 'does not touch minutes_used' do
            quota.minutes_used.should eq used
          end
        end
      end
      context 'neither plan or number of callers changes' do
        let(:used){ 250 }
        let(:allowed){ 1000 }
        let(:callers){ 1 }
        before do
          provider_object.stub(:quantity){ callers }
          quota.update_attributes!({
            minutes_used: used,
            minutes_allowed: allowed,
            callers_allowed: callers
          })
          opts.merge!({old_plan_id: 'basic'})
          quota.change_plans_or_callers(basic_plan, provider_object, opts)
        end
        it 'does not touch minutes_allowed because this action is not prorated' do
          quota.minutes_allowed.should eq allowed
        end
        it 'does not touch callers_allowed because this action is not prorated' do
          quota.callers_allowed.should eq callers
        end
        it 'does not touch minutes_used because this action is not prorated' do
          quota.minutes_used.should eq used
        end
      end
    end

    describe '#plan_changed!(new_plan, provider_object, opts)' do
      context 'Trial -> Basic (upgrade)' do
        let(:callers_allowed){ quota.callers_allowed + 2 }
        let(:opts) do
          {
            callers_allowed: callers_allowed,
            old_plan_id: 'trial'
          }
        end
        before do
          provider_object.stub(:quantity){ callers_allowed }
        end
        it 'sets `callers_allowed` to opts[:callers_allowed]' do
          quota.plan_changed!('basic', provider_object, opts)
          quota.callers_allowed.should eq callers_allowed
        end
        it 'sets `minutes_allowed` to callers_allowed * plan.minutes_per_quantity' do
          quota.plan_changed!('basic', provider_object, opts)
          quota.minutes_allowed.should eq callers_allowed * 1000
        end
      end
      context 'Basic -> Business (upgrade 5 days into billing cycle, caller does not change)' do
        let(:callers_allowed){ 1 }
        let(:opts) do
          {
            callers_allowed: callers_allowed,
            old_plan_id: 'basic',
            prorate: true
          }
        end
        before do
          provider_object.stub(:quantity){ callers_allowed }
          provider_object.stub(:current_period_start){ 5.days.ago }
          provider_object.stub(:current_period_end){ 25.days.from_now }
          quota.update_attributes!({
            callers_allowed: callers_allowed,
            minutes_allowed: 1000,
            minutes_used: 234
          })
          quota.plan_changed!('business', provider_object, opts)
        end
        it 'sets minutes_allowed = prorated(provider_object.quantity * 6000)' do
          minutes_to_add = prorated_minutes(provider_object, 6000)
          quota.minutes_allowed.should eq callers_allowed * minutes_to_add
        end
        it 'sets callers_allowed = provider_object.quantity' do
          quota.callers_allowed.should eq callers_allowed
        end
        it 'sets minutes_used = 0' do
          quota.minutes_used.should be_zero
        end
      end
      context 'Business -> Pro (downgrade 12 days into billing cycle, caller does not change)' do
        let(:callers_allowed){ 1 }
        let(:opts) do
          {
            callers_allowed: callers_allowed,
            old_plan_id: 'business'
          }
        end
        before do
          provider_object.stub(:current_period_start){ 12.days.ago }
          provider_object.stub(:current_period_end){ (30 - 12).days.from_now }
          quota.update_attributes!({
            callers_allowed: callers_allowed,
            minutes_allowed: 1000,
            minutes_used: 234
          })
          quota.plan_changed!('pro', provider_object, opts)
        end
        context 'immediately' do
          it 'sets callers_allowed = provider_object.quantity' do
            quota.callers_allowed.should eq callers_allowed
          end
          it 'does not touch minutes_allowed' do
            quota.minutes_allowed.should eq 1000
          end
          it 'does not touch minutes_used' do
            quota.minutes_used.should eq 234
          end
        end
        context 'eventually (once provider event is received and processed)' do
          it 'sets minutes_allowed = provider_object.quantity * 2500'
          it 'sets minutes_used = 0'
        end
      end
      context 'Business -> Pro -1 caller (downgrade & remove caller 9 days into billing cycle)' do
        let(:callers_allowed){ 3 }
        let(:opts) do
          {
            callers_allowed: callers_allowed - 1,
            old_plan_id: 'business'
          }
        end
        before do
          provider_object.stub(:quantity){ opts[:callers_allowed] }
          provider_object.stub(:current_period_start){ 9.days.ago }
          provider_object.stub(:current_period_end){ (30 - 9).days.from_now }
          quota.update_attributes!({
            callers_allowed: callers_allowed,
            minutes_allowed: 6000,
            minutes_used: 2345
          })
          quota.plan_changed!('pro', provider_object, opts)
        end
        context 'immediately' do
          it 'sets callers_allowed = provider_object.quantity' do
            quota.callers_allowed.should eq provider_object.quantity
          end
          it 'does not touch minutes_allowed' do
            quota.minutes_allowed.should eq 6000
          end
          it 'does not touch minutes_used' do
            quota.minutes_used.should eq 2345
          end
        end
        context 'eventually (once provider event is received and processed)' do
          it 'sets minutes_allowed = provider_object.quantity * 2500'
          it 'sets minutes_used = 0'
        end
      end
      context 'Business -> Pro +1 caller (downgrade & add caller 3 days into billing cycle)' do
        let(:callers_allowed){ 3 }
        let(:opts) do
          {
            callers_allowed: callers_allowed + 1,
            old_plan_id: 'business'
          }
        end
        before do
          provider_object.stub(:quantity){ opts[:callers_allowed] }
          provider_object.stub(:current_period_start){ 3.days.ago }
          provider_object.stub(:current_period_end){ (30 - 3).days.from_now }
          quota.update_attributes!({
            callers_allowed: callers_allowed,
            minutes_allowed: 6000,
            minutes_used: 2345
          })
          quota.plan_changed!('pro', provider_object, opts)
        end
        context 'immediately' do
          it 'sets callers_allowed = provider_object.quantity' do
            quota.callers_allowed.should eq provider_object.quantity
          end
          it 'does not touche minutes_allowed' do
            quota.minutes_allowed.should eq 6000
          end
          it 'does not touch minutes_used' do
            quota.minutes_used.should eq 2345
          end
        end
        context 'eventually (once provider event is received and processed)' do
          it 'sets minutes_allowed = provider_object.quantity * 2500'
          it 'sets minutes_used = 0'
        end
      end
      context 'Pro -> PerMinute' do
        let(:callers_allowed){ 1 }
        let(:amount_paid){ 100 * 100 } # cents
        let(:opts) do
          {
            amount_paid: amount_paid,
            old_plan_id: 'pro'
          }
        end
        before do
          provider_object.stub(:quantity){ nil }
          provider_object.stub(:current_period_start){ nil }
          provider_object.stub(:current_period_end){ nil }
          provider_object.stub(:amount){ amount_paid }
          quota.update_attributes!({
            callers_allowed: callers_allowed,
            minutes_allowed: 1000,
            minutes_used: 234
          })
          quota.plan_changed!('per_minute', provider_object, opts)
        end
        it 'sets minutes_allowed = (provider_object.amount / 9 - priced at $0.09 /minute)' do
          quota.minutes_allowed.should eq (provider_object.amount / 9).to_i
        end
        it 'sets callers_allowed = 0 - not relevant to per_minute plans' do
          quota.callers_allowed.should eq be_zero
        end
        it 'sets minutes_used = 0' do
          quota.minutes_used.should be_zero
        end
      end
      context 'Pro -> Business +2 callers (upgrade & add callers 17 days into billing cycle)' do
        let(:callers_allowed){ 1 }
        let(:allowed){ 2500 }
        let(:used){ 234 }
        let(:opts) do
          {
            callers_allowed: callers_allowed + 2,
            old_plan_id: 'pro',
            prorate: true
          }
        end
        before do
          provider_object.stub(:current_period_start){ 17.days.ago }
          provider_object.stub(:current_period_end){ (30 - 17).days.from_now }
          provider_object.stub(:quantity){ opts[:callers_allowed] }
          quota.update_attributes!({
            callers_allowed: callers_allowed,
            minutes_allowed: allowed,
            minutes_used: used
          })
          quota.plan_changed!('business', provider_object, opts)
        end
        it 'sets minutes_allowed = prorated(provider_object.quantity * 6000)' do
          quota.minutes_allowed.should eq prorated_minutes(provider_object, (6000 * provider_object.quantity))
        end
        it 'sets callers_allowed = provider_object.quantity' do
          quota.callers_allowed.should eq provider_object.quantity
        end
        it 'sets minutes_used to zero' do
          quota.minutes_used.should be_zero
        end
      end
      context 'Pro -> Business -2 callers (upgrade & remove callers 13 days into billing cycle)' do
        let(:callers_allowed){ 5 }
        let(:allowed){ 2500 }
        let(:used){ 234 }
        let(:opts) do
          {
            callers_allowed: callers_allowed - 2,
            old_plan_id: 'pro',
            prorate: true
          }
        end
        before do
          provider_object.stub(:current_period_start){ 13.days.ago }
          provider_object.stub(:current_period_end){ (30 - 13).days.from_now }
          provider_object.stub(:quantity){ opts[:callers_allowed] }
          quota.update_attributes!({
            callers_allowed: callers_allowed,
            minutes_allowed: allowed,
            minutes_used: used
          })
          quota.plan_changed!('business', provider_object, opts)
        end
        it 'sets minutes_allowed = prorated(provider_object.quantity * 6000)' do
          quota.minutes_allowed.should eq prorated_minutes(provider_object, (6000 * provider_object.quantity))
        end
        it 'sets callers_allowed = provider_object.quantity' do
          quota.callers_allowed.should eq provider_object.quantity
        end
        it 'sets minutes_used to zero' do
          quota.minutes_used.should be_zero
        end
      end
      context 'Business -> +3 callers (29 days into billing cycle)' do
        let(:callers_allowed){ 1 }
        let(:allowed){ 6000 }
        let(:used){ 2345 }
        let(:opts) do
          {
            callers_allowed: callers_allowed + 3,
            old_plan_id: 'business',
            prorate: true
          }
        end
        before do
          provider_object.stub(:current_period_start){ 29.days.ago }
          provider_object.stub(:current_period_end){ 1.day.from_now }
          provider_object.stub(:quantity){ opts[:callers_allowed] }
          quota.update_attributes!({
            callers_allowed: callers_allowed,
            minutes_allowed: allowed,
            minutes_used: used
          })
          quota.plan_changed!('business', provider_object, opts)
        end
        it 'sets minutes_allowed += prorated(added_caller_count * 6000)' do
          quota.minutes_allowed.should eq prorated_minutes(provider_object, (6000 * 3)) + allowed
        end
        it 'sets callers_allowed = provider_object.quantity' do
          quota.callers_allowed.should eq provider_object.quantity
        end
        it 'sets minutes_used to zero' do
          quota.minutes_used.should eq used
        end
      end
      context 'Basic -> PerMinute' do
        let(:callers_allowed){ 1 }
        let(:amount_paid){ 100 * 100 } # cents
        let(:opts) do
          {
            amount_paid: amount_paid,
            old_plan_id: 'basic'
          }
        end
        before do
          provider_object.stub(:quantity){ nil }
          provider_object.stub(:current_period_start){ nil }
          provider_object.stub(:current_period_end){ nil }
          provider_object.stub(:amount){ amount_paid }
          quota.update_attributes!({
            callers_allowed: callers_allowed,
            minutes_allowed: 1000,
            minutes_used: 234
          })
          quota.plan_changed!('per_minute', provider_object, opts)
        end
        it 'sets minutes_allowed = (provider_object.amount / 9 - priced at $0.09 /minute)' do
          quota.minutes_allowed.should eq (provider_object.amount / 9).to_i
        end
        it 'sets callers_allowed = 0 - not relevant to per_minute plans' do
          quota.callers_allowed.should eq be_zero
        end
        it 'sets minutes_used = 0' do
          quota.minutes_used.should be_zero
        end
      end
    end
  end
end

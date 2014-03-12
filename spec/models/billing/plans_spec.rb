require 'spec_helper'

describe Billing::Plans do
  let(:plans){ Billing::Plans.new }

  describe '#is_upgrade?(old_plan, new_plan)' do
    it 'returns true when old_plan is listed before new_plan in config' do
      truths = [
        plans.is_upgrade?('trial', 'basic'),
        plans.is_upgrade?('basic', 'pro'),
        plans.is_upgrade?('pro', 'business'),
        plans.is_upgrade?('business', 'per_minute'),
        plans.is_upgrade?('per_minute', 'enterprise')
      ]

      truths.each{|t| t.should be_true}
    end

    it 'returns false when old_plan is listed after new_plan in config' do
      lies = [
        plans.is_upgrade?('business', 'pro'),
        plans.is_upgrade?('pro', 'basic'),
        plans.is_upgrade?('basic', 'trial'),
        plans.is_upgrade?('enterprise', 'per_minute'),
        plans.is_upgrade?('business', 'basic')
      ]

      lies.each{|l| l.should be_false}
    end
  end

  describe '#buying_minutes?(plan, amount_paid)' do
    it 'returns true when plan == "per_minute" and amount_paid is greater than zero' do
      plans.buying_minutes?('per_minute').should be_true
      plans.buying_minutes?('per_minute').should be_true
      plans.buying_minutes?('per_minute').should be_true
    end

    it 'returns false otherwise' do
      plans.buying_minutes?('basic').should be_false
      plans.buying_minutes?('pro').should be_false
      plans.buying_minutes?('enterprise').should be_false
    end
  end

  describe '#recurring?(plan)' do
    it 'returns true when plan == basic' do
      plans.recurring?('basic').should be_true
    end
    it 'returns true when plan == pro' do
      plans.recurring?('pro').should be_true
    end
    it 'returns true when plan == business' do
      plans.recurring?('business').should be_true
    end
    it 'returns false when plan == per_minute' do
      plans.recurring?('per_minute').should be_false
    end
    it 'returns false when plan == enterprise' do
      plans.recurring?('enterprise').should be_false
    end
  end

  describe '#validate_transition!(old_plan, new_plan, minutes_available, opts)' do
    context 'raises InvalidPlanTransition when' do
      it 'transitioning to a recurring plan w/out a valid number of callers' do
        expect{
          plans.validate_transition!('basic', 'pro', true, {})
        }.to raise_error{ Billing::Plans::InvalidPlanTransition }
        expect{
          plans.validate_transition!('pro', 'business', true, {callers_allowed: -1})
        }.to raise_error{ Billing::Plans::InvalidPlanTransition }
        expect{
          plans.validate_transition!('pro', 'business', true, {callers_allowed: 0.5})
        }.to raise_error{ Billing::Plans::InvalidPlanTransition }
        expect{
          plans.validate_transition!('pro', 'business', true, {callers_allowed: 0})
        }.to raise_error{ Billing::Plans::InvalidPlanTransition }
      end
      it 'transitioning to a recurring plan from a per minute plan and minutes_available is true' do
        expect{
          plans.validate_transition!('per_minute', 'business', true, {callers_allowed: 2})
        }.to raise_error{ Billing::Plans::InvalidPlanTransition }
        expect{
          plans.validate_transition!('per_minute', 'pro', true, {callers_allowed: 2})
        }.to raise_error{ Billing::Plans::InvalidPlanTransition }
      end
      it 'transitioning to a per minute plan w/out a valid number of USD' do
        expect{
          plans.validate_transition!('business', 'per_minute', true, {amount_paid: 0.5})
        }.to raise_error{ Billing::Plans::InvalidPlanTransition }
        expect{
          plans.validate_transition!('per_minute', 'per_minute', true, {amount_paid: 0})
        }.to raise_error{ Billing::Plans::InvalidPlanTransition }
      end
      it 'valid_minutes_purchase?("per_minute", 0.5) should be false' do
        plans.valid_minutes_purchase?('per_minute', 0.5).should be_false
      end
    end

    context 'returns true when given valid arguments and' do
      it 'transitioning to a recurring plan from another recurring plan' do
        actual = plans.validate_transition!('trial', 'basic', true, {callers_allowed: 1})
        actual.should be_true
      end
      it 'transitioning to a per minute plan from a recurring plan' do
        actual = plans.validate_transition!('pro', 'per_minute', true, {amount_paid: 3})
        actual.should be_true
      end
      it 'adding callers to a recurring plan' do
        actual = plans.validate_transition!('basic', 'basic', true, {callers_allowed: 5})
        actual.should be_true
      end
      it 'removing callers from a recurring plan' do
        actual = plans.validate_transition!('pro', 'pro', true, {callers_allowed: 3})
        actual.should be_true
      end
      it 'adding minutes to a per minute plan' do
        actual = plans.validate_transition!('per_minute', 'per_minute', true, {amount_paid: 4})
        actual.should be_true
      end
    end
  end
end

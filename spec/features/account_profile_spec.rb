require 'spec_helper'
include JSHelpers

def select_plan(type='Basic')
  select type, from: 'Select plan:'
end

def enter_n_callers(n)
  fill_in 'Number of callers:', with: n
end

def submit_valid_upgrade
  select_plan 'Basic'
  enter_n_callers 2
  click_on 'Upgrade'
end

def fill_in_expiration
  fill_in 'Expiration date', with: "" # focus the form element
  # verify jquery datepicker is working
  page.execute_script('$("select[data-handler=\"selectMonth\"]").val("0")')
  page.execute_script('$("select[data-handler=\"selectYear\"]").val("2020")')
  page.execute_script('$("#subscription_expiration_date").val("01/2020")')
end

def add_valid_payment_info
  go_to_update_billing
  fill_in 'Card number', with: StripeFakes.valid_cards[:visa].first
  fill_in 'CVC', with: 123
  fill_in_expiration
  click_on 'Update payment information'
  page.should have_content I18n.t('subscriptions.update_billing.success')
end

def go_to_billing
  click_on 'Account'
  click_on 'Billing'
end

def go_to_upgrade
  go_to_billing
  click_on 'Upgrade'
end

def go_to_update_billing
  go_to_billing
  click_on 'Update billing info'
end

def expect_monthly_cost_eq(expected_cost)
  within('#cost-subscription') do
    page.should have_content "$#{expected_cost} per month"
  end
end

describe 'Account profile' do
  let(:user){ create(:user) }
  before do
    web_login_as(user)
  end

  describe 'Billing', js: true do
    it 'Upgrade button is disabled until payment info exists' do
      go_to_billing

      page.should_not have_text 'Upgrade'
    end

    context 'Adding valid payment info' do
      before do
        go_to_update_billing
      end

      it 'displays subscriptions.update_billing.success after form submission' do
        fill_in 'Card number', with: StripeFakes.valid_cards[:visa].first
        fill_in 'CVC', with: 123
        fill_in_expiration
        click_on 'Update payment information'
        page.should have_content I18n.t('subscriptions.update_billing.success')
      end
    end

    context 'Upgrading with valid payment info' do
      it 'displays subscriptions.upgrade.success after form submission' do
        add_valid_payment_info
        go_to_upgrade
        select_plan 'Basic'
        enter_n_callers 2
        click_on 'Upgrade'

        page.should have_content I18n.t('subscriptions.upgrade.success')
      end
    end

    describe 'Upgrade to Basic plan' do
      let(:cost){ 49 }
      let(:callers){ 2 }

      it 'performs live update of monthly cost as plan and caller inputs change' do
        add_valid_payment_info
        go_to_upgrade
        select_plan 'Basic'
        expect_monthly_cost_eq cost
        enter_n_callers callers
        expect_monthly_cost_eq "#{cost * callers}"
        click_on 'Upgrade'

        page.should have_content I18n.t('subscriptions.upgrade.success')
      end
    end

    describe 'Upgrade to Pro plan' do
      let(:cost){ 99 }
      let(:callers){ 2 }

      it 'performs live update of monthly cost as plan and caller inputs change' do
        add_valid_payment_info
        go_to_upgrade
        select_plan 'Pro'
        expect_monthly_cost_eq cost

        enter_n_callers callers
        expect_monthly_cost_eq "#{cost * callers}"

        click_on  'Upgrade'
        page.should have_content I18n.t('subscriptions.upgrade.success')
      end
    end

    describe 'Upgrade from Trial to Per minute' do
      let(:cost){ 0.09 }
      let(:minutes){ 500 }

      before do
        add_valid_payment_info
        go_to_upgrade
        select_plan 'Per minute'
      end

      it 'adds user designated amount of funds to the account' do
        fill_in 'Add to balance:', with: 500
        click_on 'Upgrade'
        page.should have_content I18n.t('subscriptions.upgrade.success')
      end

      describe 'with blank Add to balance field' do
        let(:cost){ 0.09 }
        let(:minutes){ 500 }

        before do
          add_valid_payment_info
          go_to_upgrade
          select_plan 'Per minute'
          click_on 'Upgrade'
        end

        it 'displays activerecord.errors.models.subscription.attributes.amount_paid.not_a_number' do
          error = I18n.t('activerecord.errors.models.subscription.attributes.amount_paid.not_a_number')
          page.should have_content "Add to balance #{error}"
        end
      end
    end

    describe 'Downgrading from Pro to Basic' do
      before do
        add_valid_payment_info
        go_to_upgrade
        select_plan 'Pro'
        click_on 'Upgrade'
        page.should have_content I18n.t('subscriptions.upgrade.success')
      end
      it 'performs live update of monthly cost as plan and caller inputs change' do
        go_to_upgrade
        select_plan 'Basic'
        expect_monthly_cost_eq 49
        click_on 'Upgrade'
        page.should have_content I18n.t('subscriptions.upgrade.success')
      end
    end
  end
end

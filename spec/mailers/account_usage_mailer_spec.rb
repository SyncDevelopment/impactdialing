require 'spec_helper'

describe AccountUsageMailer do
  include ExceptionMethods

  let(:white_labeled_email){ 'info@stonesphones.com' }
  let(:white_label){ 'stonesphonesdialer' }

  let(:from_date){ '2013-09-10T00:09:09+07:00' }
  let(:to_date){ '2014-01-28T23:59:59+07:00' }

  let(:campaigns){ [] }
  let(:callers){ [] }
  let(:account) do
    double('Account', {
      id: 1,
      all_campaigns: campaigns,
      callers: callers
    })
  end

  let(:user) do
    double('User', {
      account: account,
      email: 'user@test.com'
    })
  end
  let(:values){ [23, 45] }
  let(:grand_total) do
    values.inject(:+)
  end
  let(:billable_minutes) do
    double('Reports::BillableMinutes', {
      calculate_total: grand_total
    })
  end
  let(:billable_totals) do
    double('Built report', {
      values: values
    })
  end
  let(:status_totals) do
    double('Built status report', {
      :[] => 1
    })
  end
  let(:campaign_report) do
    double('Reports::Customer::ByCampaign', {
      build: billable_totals
    })
  end
  let(:caller_report) do
    double('Reports::Customer::ByCaller', {
      build: billable_totals
    })
  end
  let(:status_report) do
    double('Reports::Customer::ByStatus', {
      build: status_totals
    })
  end
  let(:date_format){ "%b %e %Y" }

  before(:each) do
    WebMock.allow_net_connect!
    @mandrill = double
    @mailer = AccountUsageMailer.new(user)
    @mailer.stub(:email_domain).and_return({'email_addresses'=>['email@impactdialing.com', white_labeled_email]})

    Reports::BillableMinutes.should_receive(:new).
      with(from_date, to_date).
      and_return(billable_minutes)
  end

  it 'delivers account-wide campaign usage report as multipart text & html' do
    Reports::Customer::ByCampaign.should_receive(:new).
      with(billable_minutes, account).
      and_return(campaign_report)

    expected_html = AccountUsageRender.new.by_campaigns(:html, billable_totals, grand_total, campaigns)
    expected_text = AccountUsageRender.new.by_campaigns(:text, billable_totals, grand_total, campaigns)

    @mailer.should_receive(:send_email).with({
      :subject => "Campaign Usage Report: #{@mailer.send(:format_date, from_date)} - #{@mailer.send(:format_date, to_date)}",
      :html => expected_html,
      :text => expected_text,
      :from_name => 'Impact Dialing',
      :from_email => 'email@impactdialing.com',
      :to=>[{email: user.email}],
      :track_opens => true,
      :track_clicks => true
    })
    @mailer.by_campaigns(from_date, to_date)
  end

  it 'delivers account-wide caller usage reports as multipart text & html' do
    Reports::Customer::ByCaller.should_receive(:new).
      with(billable_minutes, account).
      and_return(caller_report)
    Reports::Customer::ByStatus.should_receive(:new).
      with(billable_minutes, account).
      and_return(status_report)

    expected_html = AccountUsageRender.new.by_callers(:html, billable_totals, status_totals, grand_total, callers)
    expected_text = AccountUsageRender.new.by_callers(:text, billable_totals, status_totals, grand_total, callers)

    @mailer.should_receive(:send_email).with({
      :subject => "Caller Usage Report: #{@mailer.send(:format_date, from_date)} - #{@mailer.send(:format_date, to_date)}",
      :html => expected_html,
      :text => expected_text,
      :from_name => 'Impact Dialing',
      :from_email => 'email@impactdialing.com',
      :to=>[{email: user.email}],
      :track_opens => true,
      :track_clicks => true
    })
    @mailer.by_callers(from_date, to_date)
  end
end

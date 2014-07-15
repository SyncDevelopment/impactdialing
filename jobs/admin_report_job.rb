require 'reports'
require 'impact_platform/heroku'

class AdminReportJob
  @queue = :upload_download
  extend ImpactPlatform::Heroku::UploadDownloadHooks

  def self.prepare_date(date)
    date.utc.strftime("%Y-%m-%d %H:%M:%S")
  end

  def self.perform(from, to, report_type, include_undebited)
    @from_date = Time.zone.parse(from).utc.beginning_of_day
    @to_date = Time.zone.parse(to).utc.end_of_day
    billable_minutes = Reports::BillableMinutes.new(@from_date, @to_date)

    if report_type == 'All'
      report = Reports::Admin::AllByAccount.new(billable_minutes, include_undebited).build
    else
      report = Reports::Admin::EnterpriseByAccount.new(billable_minutes).build
    end

    if ["aws", "heroku"].include?(ENV['RAILS_ENV'])
      UserMailer.new.deliver_admin_report(from, to, report)
    else
      Rails.logger.info report
      p report
    end
    report
  end
end

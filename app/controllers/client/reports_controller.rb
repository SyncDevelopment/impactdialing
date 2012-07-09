require Rails.root.join("jobs/report_download_job")
module Client
  class ReportsController < ClientController
    include ApplicationHelper::TimeUtils
    include TimeZoneHelper
    before_filter :load_campaign, :except => [:index, :usage, :account_campaigns_usage, :account_callers_usage]


    def load_campaign
      @campaign = Campaign.find(params[:campaign_id])
    end

    def index
      @campaigns = params[:id].blank? ? account.campaigns.manual : Campaign.find(params[:id])
      @download_report_count = DownloadedReport.accounts_active_report_count(@campaigns.collect{|c| c.id})
      @callers = account.callers.active
    end

    
    def dials
      @from_date, @to_date = set_date_range(@campaign, params[:from_date], params[:to_date])
      @show_summary = true if params[:from_date].blank? || params[:to_date].blank?
      @dials_report = DialReport.new
      @dials_report.compute_campaign_report(@campaign, @from_date, @to_date)
    end
    
    def account_campaigns_usage
      @account = Account.find(params[:id])
      @campaigns = @account.campaigns
      puts params[:from_date]
      puts params[:to_date]
      @from_date, @to_date = set_date_range_account(@account, params[:from_date], params[:to_date])
      account_usage = AccountUsage.new(@account, @from_date, @to_date)
      @billiable_total = account_usage.billable_usage
    end
    
    def account_callers_usage
      @account = Account.find(params[:id])
      @callers = @account.callers
      @from_date, @to_date = set_date_range_account(@account, params[:from_date], params[:to_date])
      account_usage = AccountUsage.new(@account, @from_date, @to_date)
      @billiable_total = account_usage.callers_billable_usage
    end
    
        
    
    
    def usage
      @campaign = current_user.campaigns.find(params[:id])
      @from_date, @to_date = set_date_range(@campaign, params[:from_date], params[:to_date])
      @campaign_usage = CampaignUsage.new(@campaign, @from_date, @to_date)
    end
    
    
    
    def downloaded_reports
      @downloaded_reports = DownloadedReport.active_reports(@campaign.id)
    end
    
    def download_report
      @from_date, @to_date = set_date_range(@campaign, params[:from_date], params[:to_date])
      @voter_fields = VoterList::VOTER_DATA_COLUMNS
      @custom_voter_fields = @user.account.custom_voter_fields.collect{ |field| field.name}      
    end

    def download
      @from_date, @to_date = set_date_range(@campaign, params[:from_date], params[:to_date])
      Resque.enqueue(ReportDownloadJob, @campaign.id, @user.id, params[:voter_fields], params[:custom_voter_fields], params[:download_all_voters],params[:lead_dial], @from_date, @to_date, "", "webui")
      flash_message(:notice, I18n.t(:client_report_processing))
      redirect_to client_reports_url
    end

    def answer
      @from_date, @to_date = set_date_range(@campaign, params[:from_date], params[:to_date])
      @results = @campaign.answers_result(@from_date, @to_date)
      @transfers = @campaign.transfers(@from_date, @to_date)
    end

    private
    
  
    
    def sanitize(count)
      count.nil? ? 0 : count
    end
    
    
    def not_dialed_voters(range_parameters, total_dials)
      if range_parameters
        @total_voters_count - total_dials
      else
        @campaign.all_voters.enabled.by_status(Voter::Status::NOTCALLED).count
      end
    end
  end
end

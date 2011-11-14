module Client
  class CampaignsController < ::CampaignsController
    layout 'client'

    def new
      @campaign = Campaign.new(:account_id => account.id)
      @campaign.save(:validate => false)
      @callers = account.callers.active
      @lists = @campaign.voter_lists
      @voters = @campaign.all_voters.active.default_order.paginate(:page => params[:page])
      @scripts = account.scripts.manual.active

      @show_voter_buttons = @user.show_voter_buttons
      @voter_list = @campaign.voter_lists.new
    end

    def show
      check_warning
      @breadcrumb=[{"Campaigns" => client_campaigns_path}, @campaign.name]

      @callers = account.callers.active
      @lists = @campaign.voter_lists
      @voters = @campaign.all_voters.active.default_order.paginate(:page => params[:page])
      @scripts = account.scripts.manual.active

      @show_voter_buttons = @user.show_voter_buttons
      @voter_list = @campaign.voter_lists.new
      if (@campaign.robo)
        redirect_to broadcast_campaign_path(@campaign)
      end
    end

    def index
      @breadcrumb="Campaigns"
      @campaigns = account.campaigns.active.manual.paginate :page => params[:page], :order => 'id desc'
      render 'campaigns/index'
    end

    def destroy
      if !@campaign.blank?
        @campaign.update_attribute(:active, false)
      end
      flash_message(:notice, "Campaign deleted")
      redirect_to :back
    end

    def deleted
      render 'campaigns/deleted'
    end

    def setup_campaigns_paths
      @deleted_campaigns_path = client_deleted_campaigns_path
      @campaigns_path = client_campaigns_path
    end

    def update
      @campaign = Campaign.find_by_id(params[:id])
      @campaign.account = account
      @campaign.update_attributes(params[:campaign])
      @scripts = @campaign.account.scripts
      @callers = @campaign.callers
      @lists = @campaign.voter_lists
      @voter_list = @campaign.voter_lists.new
      if @campaign.valid?
        @campaign.script ||= @campaign.account.scripts.first
        @campaign.save
        if params[:listsSent]
          @campaign.disable_voter_list
          params[:voter_list_ids].each { |id| VoterList.enable_voter_list(id) } unless params[:voter_list_ids].blank?
        end
        flash_message(:notice, "Campaign saved")
        redirect_to client_campaign_path(@campaign)
      else
        render :new
      end
    end

    def create
      @campaign = Campaign.new(params[:campaign])
      @campaign.account = account
      @campaign.script ||= @campaign.account.scripts.first
      if @campaign.save
        if params[:listsSent]
          @campaign.disable_voter_list
          params[:voter_list_ids].each { |id| enable_voter_list(id) } unless params[:voter_list_ids].blank?
        end
        flash_message(:notice, "Campaign saved")
        redirect_to client_campaign_path(@campaign)
      else
        render :action=>"new"
      end
    end

    def clear_calls
      if current_user.admin?
        campaign = Campaign.find(params[:campaign_id])
        campaign.clear_calls
        flash_message(:notice, "Calls cleared")
        redirect_to client_campaign_path(campaign)
      else
        render :text => 'unauthorized', :status => :unauthorized
      end
    end
  end
end

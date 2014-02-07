require Rails.root.join("lib/twilio_lib")

class ClientController < ApplicationController
  protect_from_forgery :except => [:billing_updated, :billing_success]
  before_filter :authenticate_api
  before_filter :check_login, :except => [:login, :user_add, :forgot, :policies]
  before_filter :check_tos_accepted, :except => [:login, :forgot]
  before_filter :check_credit_card_declined

  def validate_account_presence!(account)
    if account.nil?
      logger.error("ClientController#validate_account_presence! - Account Not Found.")
      if @user.present?
        logger.error("\tfor Account[#{@user.account_id}]")
        logger.error("\tfor User[#{@user.id}:#{@user.email}]. Destroying User record.")
        # @user.destroy
        session[:user] = nil
      end

      respond_to do |format|
        format.html do
          flash_message(:error, 'Please sign in or create an account.')
          redirect_to login_path
        end
        format.json { render json: {message: 'Unauthorized request. Please provide a valid API key or create an account.', code: "401", status: "error"} }
      end

      return false
    else
      return true
    end
  end

  def authenticate_api
    unless params[:api_key].blank?
      @account = Account.find_by_api_key(params[:api_key])
      validate_account_presence!(@account) || return
      @user = @account.users.first
      session[:user] = @user.id
    end
  end

  def check_tos_accepted
    validate_account_presence!(@account) || return

    if !@account.try(:terms_and_services_accepted?)
      respond_to do |format|
          format.html { redirect_to client_tos_path    }
          format.json { render json: {message: "Please accept the Terms of services before making any request" }, code: "403" }
      end

    else
      return
    end
  end

  def check_login
    if session[:user].blank?
      respond_to do |format|
        format.json { render :json => {status: 'error', code: '401' , message: 'Unauthorized'}, :status => :unauthorized }
        format.html do
          flash_message(:error, "Please sign in.")
          redirect_to login_path
        end
      end
    end
    begin
      @user = User.find(session[:user])
      @account = @user.account
      validate_account_presence!(@account) || return
    rescue
    end
  end

  def current_user
    @user
  end

  def account
    current_user.try(:account)
  end

  def forgot
    if request.post?
      user = User.find_by_email(params[:email])
      if user.blank?
        flash_now(:error, "We could not find an account with that email address")
      else
        user.create_reset_code!
        Resque.enqueue(ResetPasswordEmailJob, user.id)
        flash_message(:notice, "We emailed your password to you. Please check your spam folder in case it accidentally ends up there.")
        redirect_to :action=>"login"
      end
    end
  end

  def caller_password
    password = params[:caller_password]
    if password.blank? || password.length < 5
      flash_message(:error, "The Account caller password can't be less than 5 characters.")
      redirect_to :back
      return
    end
    @account.update_caller_password(params[:caller_password])
    redirect_to :back
  end

  def generate_api_key
    @account.enable_api!
    redirect_to :back
  end

  def login_from_api_key
    self.current_user = Account.find_by_api_key(params[:api_key]) unless params[:api_key].empty?
  end

  def check_credit_card_declined
    if current_user.present?
      validate_account_presence!(current_user.try(:account)) || return
    end

    if current_user && !current_user.account.current_subscription.trial? && current_user.account.credit_card_declined?
      billing_link = '<a href="' + white_labeled_billing_link(request.domain) + '">Billing information</a>'
      add_to_balance_link = '<a href="' + white_labeled_add_to_balance_link(request.domain) + '">add to your balance</a>'
      configure_auto_recharge_link = '<a href="' + white_labeled_configure_auto_recharge_link(request.domain) + '">re-enable auto-recharge</a>'
      flash_now(:warning, I18n.t(:credit_card_declined, billing_link: billing_link , add_to_balance_link: add_to_balance_link, configure_auto_recharge_link: configure_auto_recharge_link).html_safe)
    end
  end

  def index
    twilio_capability = Twilio::Util::Capability.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    twilio_capability.allow_client_outgoing(MONITOR_TWILIO_APP_SID)
    @token = twilio_capability.generate
  end

  def login
    if session[:user]
      redirect_to client_root_path
    else
      @user = User.new
    end
  end

  def recording_add
    if request.post?
      @recording = @account.recordings.new(params[:recording])
      if params[:recording][:file].blank?
        flash_now(:error, "You must choose a recording to upload.")
        return
      end
      if params[:recording][:name].blank?
        flash_now(:error, "You must enter a name for the voicemail.")
        return
      end
      @recording.save!
      campaign = Campaign.find(params[:campaign_id])
      campaign.update_attribute(:recording, @recording)

      flash_message(:notice, "Vociemail added.")
      redirect_to client_campaign_path(params[:campaign_id])
      return
    else
      @recording = @account.recordings.new
    end
  end
  def policies
    render 'client/tos/policies'
  end
end

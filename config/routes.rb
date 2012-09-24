PROTOCOL = Rails.env == 'development' || Rails.env == 'heroku_staging' ? 'http://' : 'https://'

ImpactDialing::Application.routes.draw do
  root :to => "client#index"


  resources :calls, :protocol => PROTOCOL do
    member do
      post :flow
      post :call_ended
      post :hangup
      post :submit_result
      post :submit_result_and_stop
    end
  end
  
  resources :caller, :protocol => PROTOCOL, :only => [:index] do
    collection do
      get :login
      post :end_session
      post :phones_only
    end

    member do
      post :start_calling
      post :flow
      post :call_voter
      post :stop_calling
      post :skip_voter
      post :kick_caller_off_conference
      post :check_reassign
      post :new_campaign_response_panel
      post :transfer_panel
    end

  end
  

  namespace "callers" do
    resources :campaigns do
      member do
        post :callin
        match :caller_ready
      end
    end
    resources :phones_only do
      collection do
        get :report
        get :usage
        get :call_details
        get :logout
      end
    end
  end


  match '/policies', :to => 'home#policies'
  match '/client/policies', :to => 'client#policies', :as => :client_policies

  namespace 'api' do
    resources :leads
    resources :callers
    resources :voter_lists
    resources :reports
    resources 'account' do
      collection do
        get :id
      end
      resources :campaigns, only: [:index]
    end
  end

  post :receive_call, :to => 'callin#create', :protocol => PROTOCOL
  post :end_caller_session, :to =>'caller/end_session'
  post :identify_caller, :to => 'callin#identify', :protocol => PROTOCOL
  get :hold_call, :to => 'callin#hold', :protocol => PROTOCOL

  namespace 'client' do
    resources :scripts do
      collection do
        get :questions_answered
        get :possible_responses_answered
      end
      resources :script_texts, :only => [:index, :create, :show, :update, :destroy]
      resources :notes, :only => [:index, :create, :show, :update, :destroy]
      resources :questions, :only => [:index, :create, :show, :update, :destroy] do
        resources :possible_responses, :only => [:index, :create, :show, :update, :destroy]
      end
    end

    resources :caller_groups

    [:campaigns, :scripts, :callers].each do |type_plural|
      get "/deleted_#{type_plural}", :to => "#{type_plural}#deleted", :as => "deleted_#{type_plural}"
      resources type_plural, :only => [:new, :index, :show, :destroy, :create, :update, :edit] do
        put 'restore', :to => "#{type_plural}#restore"
      end
    end

    resources :callers do
      member do
        get :usage
        get :call_details
      end
      member { get :reassign_to_campaign }
    end



    resources :campaigns, :only => [] do
      resources :reports do
        collection do
          get :download_report
          post :download
          get :downloaded_reports
        end
      end
    end
    resource :account, :only => [:show, :create]
    resources :reports do
      collection do
        get :usage
        get :answer
        get :dials
        get :account_campaigns_usage
        get :account_callers_usage
      end
    end
    get :update_report_real
    resources :users, :only => [:create, :destroy]
    post 'user_invite', :to => 'users#invite', :as => 'user_invite'
    post 'caller_password', :to => 'users#caller_password', :as => 'caller_password'
    post 'generate_api_key', :to => 'users#generate_api_key', :as => 'generate_api_key'
    post 'change_role', :to => 'users#change_role', :as => 'change_role'
  end

  scope 'client' do
    match '/', :to => 'client#index', :as => 'client_root'

    resources :campaigns, :only => [] do
      member { post :verify_callerid }
    end
    resources :blocked_numbers, :only => [:index, :create, :destroy]
    resources :monitors do
      collection do
        get :start
        get :stop
        get :deactivate_session
        get :switch_mode
        get :monitor_session
        get :kick_off
      end
      match "toggle_call_recording" => "monitors#toggle_call_recording"
    end
  end

  scope 'caller' do
    match '/', :to => 'caller#index', :as => 'caller_root'
    match 'logout', :to => 'caller#logout', :as => 'caller_logout'
  end

  scope 'client' do
    resources :campaigns do
      resources :voter_lists do
        collection do
          post :import
          post :column_mapping
        end
      end
    end
  end


  resources :call_attempts, :protocol => PROTOCOL, :only => [:create, :update] do
    member do
      post :connect
      post :end
      post :disconnect
      post :voter_response
      post :hangup
    end
  end

  resources :transfer, :protocol => PROTOCOL do
    member do
      post :connect
      post :end
      post :disconnect
    end
    collection do
      post :callee
      post :caller
      post :dial
    end
  end


  resources :users do
    put '/update_password', :to => 'client/users#update_password', :as => 'update_password'
  end

  get '/reset_password', :to => 'client/users#reset_password', :as => 'reset_password'

  match '/client/login', :to => 'client#login', :as => :login
  match '/caller/login', :to => 'caller#login', :as => :caller_login

  match '/twilio_callback', :to => 'twilio#callback', :as => :twilio_callback, :protocol => PROTOCOL
  match '/twilio_callback', :to => 'twilio#callback', :as => :twilio_callback, :protocol => PROTOCOL
  match '/twilio_create_call', :to => 'twilio#create_call', :as => :twilio_create_call, :protocol => PROTOCOL

  match '/twilio_report_error', :to => 'twilio#report_error', :as => :twilio_report_error, :protocol => PROTOCOL
  match '/twilio_call_ended', :to => 'twilio#call_ended', :as => :twilio_call_ended, :protocol => PROTOCOL
  match '/recurly/notification', :to => 'recurly#notification', :as => :recurly_notification

  get 'admin/status', :to => 'admin#state'
  get 'admin/abandonment', :to => 'admin#abandonment'

  resource :call_attempts, :only => :create

  match ':controller/:action/:id'
  match ':controller/:action'
end

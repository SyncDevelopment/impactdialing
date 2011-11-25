PROTOCOL = Rails.env == 'development' ? 'http://' : 'https://'

ImpactDialing::Application.routes.draw do
  root :to => "home#index"

  ['monitor', 'how_were_different', 'pricing', 'contact', 'policies'].each do |path|
    match "/#{path}", :to => "home##{path}", :as => path
  end
  match '/client/policies', :to => 'client#policies', :as => :client_policies
  match '/broadcast/policies', :to => 'broadcast#policies', :as => :broadcast_policies
  match '/homecss/css/style.css', :to => 'home#homecss'

  namespace 'admin' do
    [:campaigns, :scripts, :callers].each do |entities|
      resources entities, :only => [:index] do
        put '/restore', :controller => entities, :action => 'restore', :as => 'restore'
      end
    end
  end

  namespace "callers" do
    resources :campaigns do
      member do
        post :callin
        match :caller_ready
      end
    end
  end

  resources :caller, :protocol => PROTOCOL, :only => [:index] do
    collection do
      get :login
      post :end_session
    end

    member do
      post :assign_campaign
      post :pause
      post :collect_response
      post :active_session
      post :preview_voter
      post :call_voter
      post :stop_calling
      post :start_calling
    end

  end

  post :receive_call, :to => 'callin#create', :protocol => PROTOCOL
  post :end_caller_session, :to =>'caller/end_session'
  post :identify_caller, :to => 'callin#identify', :protocol => PROTOCOL
  get :hold_call, :to => 'callin#hold', :protocol => PROTOCOL

  #broadcast
  scope 'broadcast' do
    resources :campaigns do
      member do
        post :verify_callerid
        post :start
        post :stop
        get :dial_statistics
      end
      collection do
        get :control
        get :running_status
      end
      resources :voter_lists, :except => [:new, :show] do
        collection { post :import }
      end
    end
    resources :reports do
      collection do
        get :usage
        get :dial_details
      end
    end
    get '/deleted_campaigns', :to => 'broadcast/campaigns#deleted', :as => :broadcast_deleted_campaigns
    resources :scripts
    match 'monitor', :to => 'monitor#index'
    match '/', :to => 'broadcast#index', :as => 'broadcast_root'
    match '/login', :to => 'broadcast#login', :as => 'broadcast_login'
  end

  namespace 'broadcast' do
    resources :campaigns, :only => [:show, :index]
  end

  namespace 'client' do
    [:campaigns, :scripts, :callers].each do |type_plural|
      get "/deleted_#{type_plural}", :to => "#{type_plural}#deleted", :as => "deleted_#{type_plural}"
      resources type_plural, :only => [:new, :index, :show, :destroy, :create, :update] do
        put 'restore', :to => "#{type_plural}#restore"
      end
    end
    resources :campaigns, :only => [] do
      resources :reports do
        collection { get :download }
      end
    end
    resource :account, :only => [:show, :update]
    resources :reports do
      collection do
        get :usage
      end
    end
    get :update_report_real

    post 'user_invite', :to => 'users#invite', :as => 'user_invite'
  end

  scope 'client' do
    match '/', :to => 'client#index', :as => 'client_root'
    resources :campaigns, :only => [] do
      member { post :verify_callerid }
      resources :voter_lists, :except => [:new, :show, :index], :name_prefix => 'client' do
        collection { post :import }
      end
    end
    resources :blocked_numbers, :only => [:index, :create, :destroy]
    resources :users, :only => [:create, :destroy]
    resources :monitors do
      collection do
        post :start
        get :stop
        get :switch_mode
        get :monitor_session
      end
    end
  end

  scope 'caller' do
    match '/', :to => 'caller#index', :as => 'caller_root'
    match 'logout', :to => 'caller#logout', :as => 'caller_logout'
  end

  resources :campaigns, :path_prefix => 'client', :only => [] do
    member { post :verify_callerid }
    resources :voter_lists, :collection => {:import => :post}, :except => [:new, :show], :name_prefix => 'client'
    match 'clear_calls', :to => 'client/campaigns#clear_calls', :as => 'clear_calls'
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

  resources :users do
    put '/update_password', :to => 'client/users#update_password', :as => 'update_password'
  end

  get '/reset_password', :to => 'client/users#reset_password', :as => 'reset_password'

  match '/client/login', :to => 'client#login', :as => :login
  match '/caller/login', :to => 'caller#login', :as => :caller_login

  match '/client/reports', :to => 'client#reports', :as => 'report'
  match '/twilio_callback', :to => 'twilio#callback', :as => :twilio_callback, :protocol => PROTOCOL
  match '/twilio_report_error', :to => 'twilio#report_error', :as => :twilio_report_error, :protocol => PROTOCOL
  match '/twilio_call_ended', :to => 'twilio#call_ended', :as => :twilio_call_ended, :protocol => PROTOCOL

  get 'admin/status', :to => 'admin#state'

  resource :call_attempts, :only => :create

  match ':controller/:action/:id'
  match ':controller/:action'
end

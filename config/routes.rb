Rails.application.routes.draw do
  post "/graphql", to: "graphql#execute"
  post "/graphql_unauthorized", to: "graphql#execute_unauthorized"
  get "/graphql_unauthorized", to: "graphql#unauthorized"
  get '_ah/health', to: proc { [200, {}, ['']] }

  devise_for :users

  namespace :api, defaults: { format: :json } do
    namespace :v3 do
      get '_ah/health', to: proc { [200, {}, ['']] }
      resources :prospects
      post 'plugin/minables/pop', to: "plugin#fetchables_pop"
      post 'plugin/status', to: "plugin#status"
      get 'plugin/pusher/whoami', to: 'plugin#whoami'
      get 'plugin/campaigns/status', to: 'plugin#campaigns_status'
      get 'plugin/customers', to: 'plugin#customers'
      get 'plugin/customers/:id/campaigns', to: 'plugin#customer_campaigns'
      # get 'plugin/is_prospected', to: 'plugin#is_prospected'
      # get 'plugin/is_same_user', to: 'plugin#is_same_user'
      # get 'plugin/check_plugin_tokens', to: 'plugin#check_plugin_tokens'
      # get 'plugin/import_histories', to: 'plugin#import_histories'
      # get 'plugin/check_prospected_by_urls', to: 'plugin#check_prospected_by_urls'
      # get 'plugin/sign_out', to: 'plugin#sign_out'
      post 'plugin/minables/incr', to: 'plugin#fetchables_incr'
      namespace :stats do
        get 'pending_requests'
        get 'all_pending_requests'
        get 'campaign_progress'
      end
      namespace :plugin do
        get "is_prospected"
        get "is_same_user"
        get "check_plugin_tokens"
        get "import_histories"
        get "check_prospected_by_ids"
        get "check_prospected_by_urls"
        get "sign_out"
        resources :fetchables, path: :minables do
          collection do
          end
        end
      end

      namespace :dnc do
        match 'check', via: [:post, :get]
      end

      post 'plugin/pusher/auth', to: 'plugin#pusher_auth'
    end
  end
end

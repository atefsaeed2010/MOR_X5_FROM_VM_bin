# -*- encoding : utf-8 -*-
Mor::Application.routes.draw do
  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  root :to => 'callc#main'

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.

  match 'test/load_delta_sql(/*path)' => 'test#load_delta_sql', via: [:get, :post]
  match 'callc/pay_subscriptions_test/:year/:month' => 'callc#pay_subscriptions_test', via: [:get, :post]
  match 'billing/callc/pay_subscriptions_test/:year/:month' => 'callc#pay_subscriptions_test', via: [:get, :post]

  match '/payment_gateways/:engine/:gateway(/:action)' => 'active_processor/gateways', :constraints => {:engine=>/gateways/}, via: [:get, :post]
  match '/payment_gateways/:engine/:gateway(/:action)' => 'active_processor/integrations', :constraints => {:engine => /integrations/}, via: [:get, :post]
  match '/payment_gateways/:engine/:gateway(/:action)' => 'active_processor/google_checkout', :constraints => {:engine => /google_checkout/}, via: [:get, :post]
  match '/payment_gateways/:engine/:gateway(/:action)' => 'active_processor/osmp', :constraints => {:engine => /osmp/}, via: [:get, :post]
  match '/payment_gateways/:engine/:gateway(/:action/:id)' => 'active_processor/ideal', :constraints => {:engine => /ideal/}, via: [:get, :post]
  match '/payment_gateways/:engine/:gateway/pay(/:id)' => 'active_processor/ideal#pay', :constraints => {:engine => /ideal/}, via: [:get, :post]
  match '/payment_gateways/:engine/:gateway/notify(/:trxid)' => 'active_processor/ideal#notify', :constraints => {:engine => /ideal/}, via: [:get, :post]

  match '/ccshop' => 'ccpanel#index', via: [:get, :post]
  match '/active_processor/callc/main' => 'callc#main', via: [:get, :post]
  match '/images/callc/login' => 'callc#login', via: [:get, :post]
  match '/active_processor/callc/logout' => 'callc#logout', via: [:get, :post]

  # for backwards compatibility, breaks if redirected withing controller
  match '/api/balance' => 'api#user_balance_get', via: [:get, :post]
  match '/api/buy_card_from_callingroup' => 'api#card_from_group_sell', via: [:get, :post]
  match '/api/callback' => 'api#callback_init', via: [:get, :post]
  match '/api/cc_by_cli' => 'api#card_by_cli_update', via: [:get, :post]
  match '/api/cli_get_info' => 'api#cli_info_get', via: [:get, :post]
  match '/api/create_payment' => 'api#payment_create', via: [:get, :post]
  match '/api/credit_notes' => 'api#credit_notes_get', via: [:get, :post]
  match '/api/device_destroy' => 'api#device_delete', via: [:get, :post]
  match '/api/device_list' => 'api#devices_get', via: [:get, :post]
  match '/api/did_assign_device' => 'api#did_device_assign', via: [:get, :post]
  match '/api/did_unassign_device' => 'api#did_device_unassign', via: [:get, :post]
  match '/api/financial_statements' => 'api#financial_statements_get', via: [:get, :post]
  match '/api/get_tariff' => 'api#tariff_rates_get', via: [:get, :post]
  match '/api/get_version' => 'api#system_version_get', via: [:get, :post]
  match '/api/import_tariff_retail' => 'api#tariff_retail_import', via: [:get, :post]
  match '/api/invoices' => 'api#invoices_get', via: [:get, :post]
  match '/api/login' => 'api#user_login', via: [:get, :post]
  match '/api/logout' => 'api#user_logout', via: [:get, :post]
  match '/api/ma_activate' => 'api#monitoring_addon_activate', via: [:get, :post]
  match '/api/ma_activate' => 'api#monitoring_addon_activate', via: [:get, :post]
  match '/api/payments_list' => 'api#payments_get', via: [:get, :post]
  match '/api/phonebooks' => 'api#phonebooks_get', via: [:get, :post]
  match '/api/rate' => 'api#rate_get', via: [:get, :post]
  match '/api/send_email' => 'api#email_send', via: [:get, :post]
  match '/api/send_sms' => 'api#sms_send', via: [:get, :post]
  match '/api/show_calling_card_group' => 'api#card_group_get', via: [:get, :post]
  match '/api/simple_balance(/:id)' => 'api#user_simple_balance_get', via: [:get, :post]
  match '/api/user_balance_change' => 'api#user_balance_update', via: [:get, :post]
  match '/api/user_calls' => 'api#user_calls_get', via: [:get, :post]
  match '/api/user_details' => 'api#user_details_get', via: [:get, :post]
  match '/api/user_update_api' => 'api#user_details_update', via: [:get, :post]
  match '/api/wholesale_tariff' => 'api#tariff_wholesale_update', via: [:get, :post]

  match '/blanks/index' => 'blanks#list', via: [:get, :post]
  match '/financial_statuses' => 'financial_statuses#list', via: [:get, :post]
  match '/m2_payments' => 'm2_payments#list', via: [:get, :post]
  match 'cards/index' => 'cards#list', via: [:get, :post]
  match '/users/index' => 'users#list', via: [:get, :post]

  #Stats URL aliases
  match '/stats/last_calls' => 'stats#last_calls_stats', via: [:get, :post]
  match '/stats/cc_call_list/:s_card_id' => 'stats#last_calls_stats', via: [:get, :post]

  match ':controller/:action.:format', via: [:get, :post]

  # turi buti paskutinis !
  match ':controller(/:action(/:id(.:format)))', via: [:get, :post]


end

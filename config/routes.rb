# frozen_string_literal: true

require "sidekiq/web"
require "sidekiq/cron/web"
require "admin_constraint"

Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  mount Sidekiq::Web => "/sidekiq", :constraints => AdminConstraint.new
  mount Flipper::UI.app(Flipper), at: "flipper", as: "flipper", constraints: AdminConstraint.new
  mount Blazer::Engine, at: "blazer", constraints: AdminConstraint.new
  get "/sidekiq", to: "users#auth" # fallback if adminconstraint fails, meaning user is not signed in
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  # API documentation
  scope "docs/api" do
    get "v2", to: "docs#v2"
    get "v2/swagger", to: "docs#swagger"

    get "v3", to: "docs#v3"
    get "v3/*path", to: "docs#v3"

    get "/", to: redirect("/docs/api/v3")
  end

  # V3 API
  mount Api::V3 => '/'

  root to: "static_pages#index"
  get "stats", to: "static_pages#stats"
  get "stats_custom_duration", to: "static_pages#stats_custom_duration"
  get "project_stats", to: "static_pages#project_stats"
  get "bookkeeping", to: "admin#bookkeeping"
  get "stripe_charge_lookup", to: "static_pages#stripe_charge_lookup"

  scope :my do
    get "/", to: redirect("/"), as: :my
    get "settings", to: "users#edit", as: :my_settings

    resources :stripe_authorizations, only: [:index, :show], path: "transactions" do
      resources :comments
    end
    get "inbox", to: "static_pages#my_inbox", as: :my_inbox
    get "missing_receipts", to: "static_pages#my_missing_receipts_list", as: :my_missing_receipts_list
    get "receipts", to: redirect("/my/inbox")
    get "receipts/:id", to: "stripe_authorizations#receipt", as: :my_receipt

    get "cards", to: "static_pages#my_cards", as: :my_cards
    get "cards/shipping", to: "stripe_cards#shipping", as: :my_cards_shipping
  end
  post "receipts/upload", to: "receipts#upload"
  delete "receipts/destroy", to: "receipts#destroy"

  post "receiptable/:receiptable_type/:receiptable_id/mark_no_or_lost", to: "receiptables#mark_no_or_lost", as: :receiptable_mark_no_or_lost

  resources :reports, only: [] do
    member do
      get "fees", to: "reports#fees"
    end
  end

  resources :users, only: [:edit, :update] do
    collection do
      get "impersonate", to: "users#impersonate"
      get "auth", to: "users#auth"
      post "auth", to: "users#auth_submit"
      get "auth/login_preference", to: "users#choose_login_preference", as: :choose_login_preference
      post "auth/login_preference", to: "users#set_login_preference", as: :set_login_preference
      post "webauthn", to: "users#webauthn_auth"
      get "webauthn/auth_options", to: "users#webauthn_options"
      post "login_code", to: "users#login_code"
      post "exchange_login_code", to: "users#exchange_login_code"

      # SMS Auth
      post "start_sms_auth_verification", to: "users#start_sms_auth_verification"
      post "complete_sms_auth_verification", to: "users#complete_sms_auth_verification"
      post "toggle_sms_auth", to: "users#toggle_sms_auth"

      # Feature-flags
      post "enable_feature", to: "users#enable_feature"
      post "disable_feature", to: "users#disable_feature"

      # Logout
      delete "logout", to: "users#logout"
      delete "logout_all", to: "users#logout_all"
      delete "logout_session", to: "users#logout_session"

      # sometimes users refresh the login code page and get 404'd
      get "exchange_login_code", to: redirect("/users/auth", status: 301)
      get "login_code", to: redirect("/users/auth", status: 301)

      # For compatibility with the previous WebAuthn login flow
      get "webauthn", to: redirect("/users/auth")
    end
    post "delete_profile_picture", to: "users#delete_profile_picture"
    patch "stripe_cardholder_profile", to: "stripe_cardholders#update_profile"

    resources :webauthn_credentials, only: [:create, :destroy] do
      collection do
        get "register_options"
      end
    end
  end

  # webhooks
  post "webhooks/donations", to: "donations#accept_donation_hook"

  resources :admin, only: [] do
    collection do
      get "twilio_messaging", to: "admin#twilio_messaging"
      get "selenium_sessions", to: "admin#selenium_sessions"
      get "selenium_sessions_new", to: "admin#selenium_sessions_new"
      post "selenium_sessions_create", to: "admin#selenium_sessions_create"
      get "transaction_csvs", to: "admin#transaction_csvs"
      post "upload", to: "admin#upload"
      get "bank_accounts", to: "admin#bank_accounts"
      get "hcb_codes", to: "admin#hcb_codes"
      get "bank_fees", to: "admin#bank_fees"
      get "users", to: "admin#users"
      get "partners", to: "admin#partners"
      get "partner/:id", to: "admin#partner", as: "partner"
      post "partner/:id", to: "admin#partner_edit"
      get "partnered_signups", to: "admin#partnered_signups"
      post "partnered_signups/:id/sign", to: "admin#partnered_signup_sign_document", as: "partnered_signup_sign_document"
      get "raw_transactions", to: "admin#raw_transactions"
      get "raw_transaction_new", to: "admin#raw_transaction_new"
      post "raw_transaction_create", to: "admin#raw_transaction_create"
      get "hashed_transactions", to: "admin#hashed_transactions"
      get "ledger", to: "admin#ledger"
      get "pending_ledger", to: "admin#pending_ledger"
      get "ach", to: "admin#ach"
      get "check", to: "admin#check"
      get "partner_organizations", to: "admin#partner_organizations"
      get "events", to: "admin#events"
      get "event_new", to: "admin#event_new"
      post "event_create", to: "admin#event_create"
      get "donations", to: "admin#donations"
      get "partner_donations", to: "admin#partner_donations"
      get "disbursements", to: "admin#disbursements"
      get "disbursement_new", to: "admin#disbursement_new"
      post "disbursement_create", to: "admin#disbursement_create"
      get "invoices", to: "admin#invoices"
      get "sponsors", to: "admin#sponsors"
      get "google_workspaces", to: "admin#google_workspaces"
      get "balances", to: "admin#balances"
    end

    member do
      get "transaction", to: "admin#transaction"
      get "event_process", to: "admin#event_process"
      put "event_toggle_approved", to: "admin#event_toggle_approved"
      put "event_reject", to: "admin#event_reject"
      get "ach_start_approval", to: "admin#ach_start_approval"
      post "ach_approve", to: "admin#ach_approve"
      post "ach_reject", to: "admin#ach_reject"
      get "disbursement_process", to: "admin#disbursement_process"
      post "disbursement_approve", to: "admin#disbursement_approve"
      post "disbursement_reject", to: "admin#disbursement_reject"
      get "check_process", to: "admin#check_process"
      get "check_positive_pay_csv", to: "admin#check_positive_pay_csv"
      post "check_send", to: "admin#check_send"
      post "check_mark_in_transit_and_processed", to: "admin#check_mark_in_transit_and_processed"
      get "google_workspace_process", to: "admin#google_workspace_process"
      post "google_workspace_approve", to: "admin#google_workspace_approve"
      post "google_workspace_update", to: "admin#google_workspace_update"
      get "invoice_process", to: "admin#invoice_process"
      post "invoice_mark_paid", to: "admin#invoice_mark_paid"

      post "partnered_signups_accept", to: "admin#partnered_signups_accept"
      post "partnered_signups_reject", to: "admin#partnered_signups_reject"
    end
  end

  post "set_event/:id", to: "admin#set_event", as: :set_event
  get "transactions/dedupe", to: "admin#transaction_dedupe", as: :transaction_dedupe

  resources :organizer_position_invites, only: [:show], path: "invites" do
    post "accept"
    post "reject"
    post "cancel"
  end

  resources :organizer_positions, only: [:destroy], as: "organizers" do
    resources :organizer_position_deletion_requests, only: [:new], as: "remove"
  end

  resources :organizer_position_deletion_requests, only: [:index, :show, :create] do
    post "close"
    post "open"

    resources :comments
  end

  resources :g_suite_accounts, only: [:index, :create, :update, :edit, :destroy], path: "g_suite_accounts" do
    put "reset_password"
    put "toggle_suspension"
    get "verify", to: "g_suite_account#verify"
    post "reject"
  end

  resources :g_suites, except: [:new, :create, :edit, :update] do
    resources :g_suite_accounts, only: [:create]

    resources :comments
  end

  resources :sponsors

  resources :invoices, only: [:show] do
    get "manual_payment"
    post "manually_mark_as_paid"
    post "archive"
    post "unarchive"
    resources :comments
  end

  resources :stripe_authorizations, only: [:show, :index] do
    resources :comments
  end
  resources :stripe_cardholders, only: [:new, :create, :update]
  resources :stripe_cards, only: %i[create index show] do
    post "freeze"
    post "defrost"
  end
  resources :emburse_cards, except: %i[new create]

  resources :checks, only: [:show] do
    get "view_scan"
    post "cancel"
    get "positive_pay_csv"

    get "start_void"
    post "void"
    get "refund", to: "checks#refund_get"
    post "refund", to: "checks#refund"

    resources :comments
  end

  resources :ach_transfers, only: [:show] do
    resources :comments
  end

  resources :ach_transfers do
    get "confirmation", to: "ach_transfers#transfer_confirmation_letter"
  end

  resources :disbursements, only: [:index, :new, :create, :show, :edit, :update] do
    post "mark_fulfilled"
    post "reject"
  end

  resources :disbursements do
    get "confirmation", to: "disbursements#transfer_confirmation_letter"
  end

  resources :comments, only: [:edit, :update]

  resources :documents, except: [:index] do
    collection do
      get "", to: "documents#common_index", as: :common
    end
    get "download"
  end

  resources :bank_accounts, only: [:new, :create, :update, :show, :index] do
    get "reauthenticate"
  end

  resources :hcb_codes, path: "/hcb", only: [:show] do
    member do
      post "comment"
      post "receipt"
      get "attach_receipt"
      get "dispute"
      post "toggle_tag/:tag_id", to: "hcb_codes#toggle_tag", as: :toggle_tag
    end

    resources :comments
  end

  resources :canonical_pending_transactions, only: [:show, :edit] do
    member do
      post "set_custom_memo"
    end
  end

  resources :canonical_transactions, only: [:show, :edit] do
    member do
      post "waive_fee"
      post "unwaive_fee"
      post "mark_bank_fee"
      post "set_custom_memo"
    end

    resources :comments
  end

  resources :transactions, only: [:index, :show, :edit, :update] do
    collection do
      get "export"
    end
    resources :comments
  end

  resources :fee_reimbursements, only: [:show, :edit, :update] do
    collection do
      get "export"
    end
    post "mark_as_processed"
    post "mark_as_unprocessed"
    resources :comments
  end

  get "branding", to: "static_pages#branding"
  get "faq", to: "static_pages#faq"

  get "audit", to: "admin#audit"

  resources :central, only: [:index] do
    collection do
      get "ledger"
    end
  end

  resources :emburse_card_requests, path: "emburse_card_requests", except: [:new, :create] do
    collection do
      get "export"
    end
    post "reject"
    post "cancel"

    resources :comments
  end

  resources :emburse_transfers, except: [:new, :create] do
    collection do
      get "export"
    end
    post "accept"
    post "reject"
    post "cancel"
    resources :comments
  end

  resources :emburse_transactions, only: [:index, :edit, :update, :show] do
    resources :comments
  end

  resources :donations, only: [:show] do
    collection do
      get "start/:event_name", to: "donations#start_donation", as: "start_donation"
      post "start/:event_name", to: "donations#make_donation", as: "make_donation"
      get "qr/:event_name.png", to: "donations#qr_code", as: "qr_code"
      get ":event_name/:donation", to: "donations#finish_donation", as: "finish_donation"
      get "export"
    end

    member do
      post "refund", to: "donations#refund"
    end

    resources :comments
  end

  resources :partner_donations, only: [:show] do
    collection do
      get "export"
    end
  end

  namespace :api do
    get "v2/login", to: "v2#login"

    post "v2/donations/new", to: "v2#donations_new"

    get "v2/organizations", to: "v2#organizations"
    get "v2/organization/:public_id", to: "v2#organization", as: :v2_organization
    post "v2/organization/:public_id/generate_login_url", to: "v2#generate_login_url", as: :v2_generate_login_url

    post "v2/partnered_signups/new", to: "v2#partnered_signups_new"
    get "v2/partnered_signups", to: "v2#partnered_signups"
    get "v2/partnered_signup/:public_id", to: "v2#partnered_signup", as: :v2_partnered_signup
  end

  get "partnered_signups/:public_id", to: "partnered_signups#edit", as: :edit_partnered_signups
  patch "partnered_signups/:public_id", to: "partnered_signups#update", as: :update_partnered_signups

  get "api/v1/events/find", to: "api#event_find" # to be deprecated
  post "api/v1/disbursements", to: "api#disbursement_new" # to be deprecated

  post "stripe/webhook", to: "stripe#webhook"
  get "docusign/signing_complete_redirect", to: "docusign#signing_complete_redirect"

  post "export/finances", to: "exports#financial_export"

  get "negative_events", to: "admin#negative_events"

  get "admin_tasks", to: "admin#tasks"
  get "admin_task_size", to: "admin#task_size"
  get "admin_search", to: "admin#search"
  post "admin_search", to: "admin#search"

  resources :ops_checkins, only: [:create]

  get "/integrations/frankly" => "integrations#frankly"

  post "twilio/messaging", to: "admin#twilio_messaging"

  match "/404", to: "errors#not_found", via: :all
  match "/500", to: "errors#internal_server_error", via: :all

  get "/events" => "events#index"
  get "/event_by_airtable_id/:airtable_id" => "events#by_airtable_id"
  resources :events, except: [:new, :create], path_names: { edit: "settings" }, path: "/" do
    get "edit", to: redirect("/%{event_id}/settings")
    get "fees", to: "events#fees", as: :fees
    get "dashboard_stats", to: "events#dashboard_stats", as: :dashboard_stats
    put "toggle_hidden", to: "events#toggle_hidden"

    post "remove_header_image"
    post "remove_logo"

    get "team", to: "events#team", as: :team
    get "google_workspace", to: "events#g_suite_overview", as: :g_suite_overview
    post "g_suite_create", to: "events#g_suite_create", as: :g_suite_create
    put "g_suite_verify", to: "events#g_suite_verify", as: :g_suite_verify
    get "emburse_cards", to: "events#emburse_card_overview", as: :emburse_cards_overview
    get "cards", to: "events#card_overview", as: :cards_overview
    get "cards/new", to: "stripe_cards#new"
    get "stripe_cards/shipping", to: "stripe_cards#shipping", as: :stripe_cards_shipping

    # (@eilla1) these pages are for the wip resources page and will be moved later
    get "connect_gofundme", to: "events#connect_gofundme", as: :connect_gofundme
    get "receive_check", to: "events#receive_check", as: :receive_check
    get "sell_merch", to: "events#sell_merch", as: :sell_merch

    get "documentation", to: "events#documentation", as: :documentation
    get "transfers", to: "events#transfers", as: :transfers
    get "promotions", to: "events#promotions", as: :promotions
    get "reimbursements", to: "events#reimbursements", as: :reimbursements
    get "donations", to: "events#donation_overview", as: :donation_overview
    get "partner_donations", to: "events#partner_donation_overview", as: :partner_donation_overview
    get "bank_fees", to: "events#bank_fees", as: :bank_fees
    resources :disbursements, only: [:new, :create]
    resources :checks, only: [:new, :create]
    resources :ach_transfers, only: [:new, :create]
    resources :organizer_position_invites,
              only: [:new, :create],
              path: "invites"
    resources :g_suites, only: [:new, :create, :edit, :update]
    resources :documents, only: [:index]
    get "fiscal_sponsorship_letter", to: "documents#fiscal_sponsorship_letter"
    resources :invoices, only: [:new, :create, :index]
    resources :stripe_authorizations, only: [:show] do
      resources :comments
    end
    resources :tags, only: [:create]
  end

  # rewrite old event urls to the new ones not prefixed by /events/
  get "/events/*path", to: redirect("/%{path}", status: 302)

  # Beware: Routes after "resources :events" might be overwritten by a
  # similarly named event
end

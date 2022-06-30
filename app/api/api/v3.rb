# frozen_string_literal: true

module Api
  class V3 < Grape::API
    include Grape::Kaminari

    version 'v3', using: :path
    prefix :api
    format :json
    default_format :json

    helpers do
      def org
        @org ||=
          begin
            id = params[:organization_id]
            event ||= Event.transparent.find_by_public_id id # by public id (ex. org_1234). Will NOT error if not found
            event ||= Event.transparent.find id # by slug or numeric id. Will error if not found
          end
      rescue ActiveRecord::RecordNotFound
        error!({ message: 'Organization not found.' }, 404)
      end

      def transactions
        # TODO: this can be optimized
        @transactions ||=
          begin
            pending = PendingTransactionEngine::PendingTransaction::All.new(event_id: org.id).run
            settled = TransactionGroupingEngine::Transaction::All.new(event_id: org.id).run

            combined = paginate(Kaminari.paginate_array(pending + settled))
            combined.map(&:local_hcb_code)
          end
      end

      def transaction
        @transaction ||=
          begin
            id = params[:transaction_id]
            HcbCode.find_by_public_id!(id)
          end
      rescue ActiveRecord::RecordNotFound
        error!({ message: 'Transaction not found.' }, 404)
      end

      def donations
        @donations ||= paginate(org.donations)
      end

      def donation
        @donation ||=
          begin
            id = params[:donation_id]
            Donation.find_by_public_id!(id)
          end
      rescue ActiveRecord::RecordNotFound
        error!({ message: 'Donation not found.' }, 404)
      end

      def transfers
        @transfers ||= paginate(org.disbursements)
      end

      def transfer
        @transfer ||=
          begin
            id = params[:transfer_id]
            Disbursement.find_by_public_id!(id)
          end
      rescue ActiveRecord::RecordNotFound
        error!({ message: 'Transfer not found.' }, 404)
      end

      def ach_transfers
        @ach_transfers ||= paginate(org.ach_transfers)
      end

      def ach_transfer
        @ach_transfer ||=
          begin
            id = params[:ach_transfer_id]
            AchTransfer.find_by_public_id!(id)
          end
      rescue ActiveRecord::RecordNotFound
        error!({ message: 'Ach transfer not found.' }, 404)
      end

      def invoices
        @invoices ||= paginate(org.invoices)
      end

      def invoice
        @invoice ||=
          begin
            id = params[:invoice_id]
            Invoice.find_by_public_id!(id)
          end
      rescue ActiveRecord::RecordNotFound
        error!({ message: 'Invoice not found.' }, 404)
      end

      def checks
        @checks ||= paginate(org.checks)
      end

      def check
        @check ||=
          begin
            id = params[:check_id]
            Check.find_by_public_id!(id)
          end
      rescue ActiveRecord::RecordNotFound
        error!({ message: 'Check not found.' }, 404)
      end

      # FOR TYPE EXPANSION
      # TODO: needs a better name
      def type_expansion(expand: [], hide: [])
        {
          expand: (params[:expand] || []) + expand,
          hide: (params[:hide] || []) + hide
        }
      end

      params :expand do
        # TODO: it see like the `Array` type is broken. It won't show on Stoplight
        optional :expand,
                 types: [String, Array[String]],
                 # TODO: this `coerce_with` is temporarily really messy because it needs to handle both processing strings and arrays of strings
                 coerce_with: ->(x) {
                   [x].flatten.compact.map { |type| type.split(',') }
                      .flatten.map { |type| type.strip.underscore }
                 },
                 desc: "Object types to expand in the API response"

        optional :hide,
                 types: [String, Array[String]],
                 # TODO: this `coerce_with` is temporarily really messy because it needs to handle both processing strings and arrays of strings
                 coerce_with: ->(x) {
                   [x].flatten.compact.map { |type| type.split(',') }
                      .flatten.map { |type| type.strip.underscore }
                 },
                 documentation: { hidden: true }
      end
    end

    desc 'Flavor text!' do
      summary "Flavor text!"
      failure [[404]]
      hidden true
    end
    get :flavor do
      content_type "text/plain"
      StaticPagesHelper.flavor_text
    end

    resource :organizations do
      desc 'Return a transparent organization' do
        summary 'Get a single organization'
        detail "The organization must be in <a href='https://changelog.bank.hackclub.com/transparent-finances-(optional-feature)-151427'><strong>Transparency Mode</strong></a>."
        produces ['application/json']
        consumes ['application/json']
        success Entities::Organization
        failure [[404, "Organization not found. Check the id/slug and make sure Transparency Mode is on.", Entities::ApiError]]
        tags ["Organizations"]
        nickname "get-a-single-organization"
      end
      params do
        requires :organization_id, type: String, desc: 'Organization ID or slug.'
        use :expand
      end
      route_param :organization_id do
        get do
          begin
            present org, with: Api::Entities::Organization, **type_expansion(expand: %w[organization user])
          rescue ActiveRecord::RecordNotFound, ArgumentError
            error!({ message: 'Organization not found.' }, 404)
          end
        end

        resource :transactions do
          desc 'Return a list of transactions' do
            summary "List an organization's transactions"
            detail "Transaction represent a line item on an Organization's ledger. There are various <em>types</em> of transaction (see the <em>type</em> below).<br/><br/>"
            produces ['application/json']
            consumes ['application/json']
            is_array true
            success Entities::Transaction
            failure [[404, "Organization not found. Check the id/slug and make sure Transparency Mode is on.", Entities::ApiError]]
            tags ["Transactions"]
            nickname "list-an-organizations-transactions"
          end
          params do
            use :pagination, per_page: 50, max_per_page: 500
            use :expand
          end
          get do
            present transactions, with: Api::Entities::Transaction, **type_expansion(expand: %w[transaction])
          end
        end

        resource :donations do
          desc 'Return a list of donations' do
            summary "List an organization's donations"
            detail ''
            produces ['application/json']
            consumes ['application/json']
            is_array true
            success Entities::Donation
            failure [[404, "Organization not found. Check the id/slug and make sure Transparency Mode is on.", Entities::ApiError]]
            tags ["Donations"]
            nickname "list-an-organizations-donations"
          end
          params do
            use :pagination, per_page: 50, max_per_page: 500
            use :expand
          end
          get do
            present donations, with: Api::Entities::Donation, **type_expansion(expand: %w[donation])
          end
        end

        resource :transfers do
          desc 'Return a list of transfers' do
            summary "List an organization's transfers"
            detail ''
            produces ['application/json']
            consumes ['application/json']
            is_array true
            success Entities::Transfer
            failure [[404, "Organization not found. Check the id/slug and make sure Transparency Mode is on.", Entities::ApiError]]
            tags ["Transfers"]
            nickname "list-an-organizations-transfers"
          end
          params do
            use :pagination, per_page: 50, max_per_page: 500
            use :expand
          end
          get do
            present transfers, with: Api::Entities::Transfer, **type_expansion(expand: %w[transfer])
          end
        end

        resource :invoices do
          desc 'Return a list of invoices' do
            summary "List an organization's invoices"
            detail ''
            produces ['application/json']
            consumes ['application/json']
            is_array true
            success Entities::Invoice
            failure [[404, "Organization not found. Check the id/slug and make sure Transparency Mode is on.", Entities::ApiError]]
            tags ["Invoices"]
            nickname "list-an-organizations-invoices"
          end
          params do
            use :pagination, per_page: 50, max_per_page: 500
            use :expand
          end
          get do
            present invoices, with: Api::Entities::Invoice, **type_expansion(expand: %w[invoice])
          end
        end

        resource :ach_transfers do
          desc 'Return a list of ACH transfers' do
            summary "List an organization's ACH transfers"
            detail ''
            produces ['application/json']
            consumes ['application/json']
            is_array true
            success Entities::AchTransfer
            failure [[404, "Organization not found. Check the id/slug and make sure Transparency Mode is on.", Entities::ApiError]]
            tags ["ACH Transfers"]
            nickname "list-an-organizations-ach-transfers"
          end
          params do
            use :pagination, per_page: 50, max_per_page: 500
            use :expand
          end
          get do
            present ach_transfers, with: Api::Entities::AchTransfer, **type_expansion(expand: %w[ach_transfer])
          end
        end

        resource :checks do
          desc 'Return a list of checks' do
            summary "List an organization's checks"
            detail ''
            produces ['application/json']
            consumes ['application/json']
            is_array true
            success Entities::Check
            failure [[404, "Organization not found. Check the id/slug and make sure Transparency Mode is on.", Entities::ApiError]]
            tags ["Checks"]
            nickname "list-an-organizations-checks"
          end
          params do
            use :pagination, per_page: 50, max_per_page: 500
            use :expand
          end
          get do
            present checks, with: Api::Entities::Check, **type_expansion(expand: %w[check])
          end
        end

      end

    end

    resource :donations do
      desc 'Return a single donation' do
        summary "Get a single donation"
        detail ''
        produces ['application/json']
        consumes ['application/json']
        success Entities::Donation
        failure [[404, "Donation not found. Check the ID.", Entities::ApiError]]
        tags ["Donations"]
        nickname "get-a-single-donation"
      end
      params do
        requires :donation_id, type: String, desc: 'Donation ID'
        use :expand
      end
      route_param :donation_id do
        get do
          present donation, with: Api::Entities::Donation, **type_expansion(expand: %w[donation])
        end
      end
    end

    resource :transfers do
      desc 'Return a single transfer' do
        summary "Get a single transfer"
        detail ''
        produces ['application/json']
        consumes ['application/json']
        success Entities::Transfer
        failure [[404, "Transfer not found. Check the ID.", Entities::ApiError]]
        tags ["Transfers"]
        nickname "get-a-single-transfer"
      end
      params do
        requires :transfer_id, type: String, desc: 'Transfer ID'
        use :expand
      end
      route_param :transfer_id do
        get do
          present transfer, with: Api::Entities::Transfer, **type_expansion(expand: %w[transfer])
        end
      end
    end

    resource :invoices do
      desc 'Return a single invoice' do
        summary "Get a single invoice"
        detail ''
        produces ['application/json']
        consumes ['application/json']
        success Entities::Invoice
        failure [[404, "Invoice not found. Check the ID.", Entities::ApiError]]
        tags ["Invoices"]
        nickname "get-a-single-invoice"
      end
      params do
        requires :invoice_id, type: String, desc: 'Invoice ID'
        use :expand
      end
      route_param :invoice_id do
        get do
          present invoice, with: Api::Entities::Invoice, **type_expansion(expand: %w[invoice])
        end
      end
    end

    resource :ach_transfers do
      desc 'Return a single ACH transfer' do
        summary "Get a single ACH transfer"
        detail ''
        produces ['application/json']
        consumes ['application/json']
        success Entities::AchTransfer
        failure [[404, "ACH transfer not found. Check the ID.", Entities::ApiError]]
        tags ["ACH Transfers"]
        nickname "get-a-single-ach-transfer"
      end
      params do
        requires :ach_transfer_id, type: String, desc: 'ACH transfer ID'
        use :expand
      end
      route_param :ach_transfer_id do
        get do
          present ach_transfer, with: Api::Entities::AchTransfer, **type_expansion(expand: %w[ach_transfer])
        end
      end
    end

    resource :checks do
      desc 'Return a single check' do
        summary "Get a single check"
        detail ''
        produces ['application/json']
        consumes ['application/json']
        success Entities::Check
        failure [[404, "Check not found. Check the ID.", Entities::ApiError]]
        tags ["Checks"]
        nickname "get-a-single-check"
      end
      params do
        requires :check_id, type: String, desc: 'Check ID'
        use :expand
      end
      route_param :check_id do
        get do
          present check, with: Api::Entities::Check, **type_expansion(expand: %w[check])
        end
      end
    end

    resource :transactions do
      desc 'Return a single transaction' do
        summary "Get a single transaction"
        detail ''
        produces ['application/json']
        consumes ['application/json']
        success Entities::Transaction
        failure [[404, "Transaction not found. Check the ID.", Entities::ApiError]]
        tags ["Transactions"]
        nickname "get-a-single-transaction"
      end
      params do
        requires :transaction_id, type: String, desc: 'Transaction ID'
        use :expand
      end
      route_param :transaction_id do
        get do
          present transaction, with: Api::Entities::Transaction, **type_expansion(expand: %w[transaction])
        end
      end
    end

    # Handle validation errors
    rescue_from Grape::Exceptions::ValidationErrors do |e|
      error!({ message: e.message }, 400)
    end

    # Handle 404 errors (catch all)
    route :any, '*path' do
      error!({ message: 'Path not found. Please see the documentation (https://bank.hackclub.com/docs/api/v3/) for all available paths.' }, 404)
    end

    # Handle unexpected errors
    rescue_from ActiveRecord::RecordNotFound do
      error!({ message: 'Not found.' }, 404)
    end
    rescue_from :all do |e|
      Airbrake.notify(e)

      # Provide error message in api response ONLY in development mode
      msg = if Rails.env.development?
              e.message
            else
              'A server error has occurred.'
            end
      error!({ message: msg }, 500)
    end

    add_swagger_documentation(
      {
        info: {
          title: "The Hack Club Bank API",
          description: "The Hack Club Bank API is an unauthenticated REST API that allows you to read public information
                        from organizations with <a href='https://changelog.bank.hackclub.com/transparent-finances-(optional-feature)-151427'>Transparency Mode</a>
                        enabled.
                        <br><br><strong>Questions or suggestions?</strong>
                        <br>Reach us in the #bank channel on the <a href='https://hackclub.com/slack'>Hack Club Slack</a>
                        or email <a href='mailto:bank@hackclub.com'>bank@hackclub.com</a>.
                        <br><br>Happy hacking! ✨",
          contact_name: "Hack Club Bank",
          contact_email: "bank@hackclub.com",
        },
        doc_version: '3.0.0',
        models: [
          Entities::Organization,
          Entities::Transaction,
          Entities::AchTransfer,
          Entities::Check,
          Entities::Transfer,
          Entities::Donation,
          Entities::Invoice,
          Entities::User,
          Entities::ApiError
        ],
        array_use_braces: true,
      }
    )

  end
end

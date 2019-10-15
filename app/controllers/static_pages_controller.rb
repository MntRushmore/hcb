class StaticPagesController < ApplicationController
  skip_after_action :verify_authorized # do not force pundit
  skip_before_action :signed_in_user, only: [:stats, :branding]

  def index
    if signed_in?
      @events = current_user.events
      @invites = current_user.organizer_position_invites.pending

      if @events.size == 1 && @invites.size == 0
        redirect_to current_user.events.first
      end
    end
    if admin_signed_in?
      @transaction_volume = Transaction.total_volume
      @active = {
        card_requests: CardRequest.under_review.size,
        checks: Check.pending.size + Check.unfinished_void.size,
        ach_transfers: AchTransfer.pending.size,
        pending_fees: Event.pending_fees.size,
        negative_events: Event.negatives.size,
        fee_reimbursements: FeeReimbursement.unprocessed.size,
        load_card_requests: LoadCardRequest.under_review.size,
        g_suite_applications: GSuiteApplication.under_review.size,
        g_suite_accounts: GSuiteAccount.under_review.size,
        transactions: Transaction.uncategorized.size,
        emburse_transactions: EmburseTransaction.under_review.size,
        organizer_position_deletion_requests: OrganizerPositionDeletionRequest.under_review.size
      }
    end
  end

  def pending_fees
    @pending_fees = Event.pending_fees.sort_by { |event| (DateTime.now - event.transactions.first.date) }.reverse
  end

  def branding
    @logos = [
      { name: 'Original Light', criteria: 'For white or light colored backgrounds.', background: 'smoke' },
      { name: 'Original Dark', criteria: 'For black or dark colored backgrounds.', background: 'black' },
      { name: 'Outlined Black', criteria: 'For white or light colored backgrounds.', background: 'snow' },
      { name: 'Outlined White', criteria: 'For black or dark colored backgrounds.', background: 'black' }
    ]
    @event_name = signed_in? ? current_user.events.first.name : 'Hack Pennsylvania'
  end

  def negative_events
    @negative_events = Event.negatives.sort_by { |event| event.balance > event.balance_not_feed ? event.balance_not_feed : event.balance }
  end

  def stats
    render json: {
      transactions_volume: Transaction.total_volume,
      transactions_count: Transaction.all.size,
      events_count: Event.all.size,
      # card_transactions_volume: EmburseTransaction.total_card_transaction_volume,
      # card_transactions_count: EmburseTransaction.total_card_transaction_count
    }
  end
end

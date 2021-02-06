require 'net/http'

class StaticPagesController < ApplicationController
  skip_after_action :verify_authorized # do not force pundit
  skip_before_action :signed_in_user, only: [:stats, :branding, :faq]

  def index
    if signed_in?
      attrs = {
        current_user: current_user
      }
      @service = StaticPageService::Index.new(attrs)

      @events = @service.events
      @invites = @service.invites
    end
    if admin_signed_in?
      @transaction_volume = Transaction.total_volume
    end
  end

  def branding
    @logos = [
      { name: 'Original Light', criteria: 'For white or light colored backgrounds.', background: 'smoke' },
      { name: 'Original Dark', criteria: 'For black or dark colored backgrounds.', background: 'black' },
      { name: 'Outlined Black', criteria: 'For white or light colored backgrounds.', background: 'snow' },
      { name: 'Outlined White', criteria: 'For black or dark colored backgrounds.', background: 'black' }
    ]
    @event_name = signed_in? && current_user.events.first ? current_user.events.first.name : 'Hack Pennsylvania'
  end

  def faq
  end

  def my_cards
    flash[:success] = 'Card activated!' if params[:activate]
    @stripe_cards = current_user.stripe_cards.includes(:event)
    @emburse_cards = current_user.emburse_cards.includes(:event)
  end

  # async frame
  def my_stripe_authorizations_list
    @authorizations = current_user.stripe_authorizations.includes(stripe_card: :event).awaiting_receipt.limit(5)
    if @authorizations.any?
      render :my_stripe_authorizations_list, layout: !request.xhr?
    else
      head :ok
    end
  end

  def my_inbox
    @authorizations = current_user.stripe_authorizations.includes(stripe_card: :event).awaiting_receipt
    @transactions = current_user.emburse_transactions.includes(emburse_card: :event).awaiting_receipt
    @txs = @authorizations + @transactions
    @count = @txs.size
  end

  def stats
    now = params[:date].present? ? Date.parse(params[:date]) : DateTime.current
    year_ago = now - 1.year
    qtr_ago = now - 3.month
    month_ago = now - 1.month

    events_list = []
    Event.where('created_at <= ?', now).order(created_at: :desc).limit(10).each { |event|
      events_list.push({
        created_at: event.created_at.to_i, # unix timestamp
      })
    }

    render json: {
      date: now,
      transactions_volume: Transaction.where('transactions.created_at <= ?', now).total_volume,
      transactions_count: Transaction.where('created_at <= ?', now).size,
      events_count: Event.where('created_at <= ?', now).size,
      # Transactions are sorted by date DESC by default, so first one is... chronologically last
      last_transaction_date: Transaction.where('created_at <= ?', now).first.created_at.to_i,
      raised: Transaction.raised_during(DateTime.strptime('0', '%s'), now),
      last_year: {
        transactions_volume: Transaction.volume_during(year_ago, now),
        revenue: Transaction.revenue_during(year_ago, now),
        raised: Transaction.raised_during(year_ago, now),
      },
      last_qtr: {
        transactions_volume: Transaction.volume_during(qtr_ago, now),
        revenue: Transaction.revenue_during(qtr_ago, now),
        raised: Transaction.raised_during(qtr_ago, now),
      },
      last_month: {
        transactions_volume: Transaction.volume_during(month_ago, now),
        revenue: Transaction.revenue_during(month_ago, now),
        raised: Transaction.raised_during(month_ago, now),
      },
      events: events_list,
    }
  end

  def stripe_charge_lookup
    id = params[:id]
    payment_intent_id = StripeService::Charge.retrieve(id)['payment_intent']
    @payment = Donation.find_by(stripe_payment_intent_id: payment_intent_id)
    @payment ||= Invoice.find_by(stripe_payment_intent_id: payment_intent_id)
    @event = @payment.event

    render json: {
      event_id: @event.id
    }
  rescue StripeService::InvalidRequestError => e
    render json: {
      event_id: nil
    }
  end
end

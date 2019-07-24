module InvoicesHelper
  def invoice_sent_at(invoice = @invoice)
    format_datetime invoice.created_at
  end

  def invoice_paid_at(invoice = @invoice)
    timestamp = invoice.manually_marked_as_paid_at || invoice&.payout&.created_at
    timestamp ? format_datetime(timestamp) : '–'
  end

  def invoice_payment_method(invoice = @invoice)
    if invoice.manually_marked_as_paid?
      return '–'
    elsif invoice&.payout
      return invoice.payout.source_type.humanize
    end
  end

  def invoice_hcb_percent(humanized = true, invoice = @invoice)
    percent = invoice.event.sponsorship_fee
    percent ||= invoice.payout.t_transaction.fee_relationship.fee_percent

    return nil if percent == 0
    return percent unless humanized

    number_to_percentage percent * 100, precision: 0
  end

  def invoice_payment_processor_fee(humanized = true, invoice = @invoice)
    fee = invoice.manually_marked_as_paid? ? 0 : invoice.item_amount - invoice.payout.amount

    return fee unless humanized

    render_money fee
  end

  def invoice_hcb_revenue(humanized = true, invoice = @invoice)
    fee = invoice.payout.t_transaction.fee_relationship.fee_percent
    revenue = fee.present? ? invoice.item_amount * fee : 0

    unless invoice.fee_reimbursed?
      # (max@maxwofford.com) before we reimbursed Stripe fees, we calculated
      # our fee from the invoice payout amount *after* Stripe fees were
      # deducted
      revenue = invoice.payout.t_transaction.fee_relationship.fee_amount
    end

    return revenue unless humanized

    render_money revenue
  end

  def invoice_hcb_profit(humanized = true, invoice = @invoice)
    profit = invoice_hcb_revenue(false) - invoice_payment_processor_fee(false)

    return profit unless humanized

    render_money profit
  end

  def invoice_event_profit(humanized = true, invoice = @invoice)
    profit = invoice.item_amount * (1 - invoice_hcb_percent(false))

    unless invoice.fee_reimbursed?
      # (max@maxwofford.com) before we reimbursed Stripe fees, event fees were
      # calculated as a percent of the payout
      profit = invoice.item_amount - invoice_payment_processor_fee(false) - invoice_hcb_revenue(false)
    end

    return profit unless humanized

    render_money profit
  end
end

def invoice_payment_method_mention(invoice = @invoice)
  return '–' unless invoice.manually_marked_as_paid? || invoice&.payment_method_type

  if invoice.manually_marked_as_paid?
    icon_name = 'post-fill'
    description_text = 'Manually marked as paid'
  elsif invoice&.payment_method_card_brand
    brand = invoice&.payment_method_card_brand
    last4 = invoice&.payment_method_card_last4

    icon_name = {
      'amex' => 'card-amex',
      'mastercard' => 'card-mastercard',
      'visa' => 'card-visa'
    }[brand] || 'card-other'
    tooltip = {
      'amex' => 'American Express',
      'mastercard' => 'Mastercard',
      'visa' => 'Visa'
    }[brand] || description_text
    tooltip += " ending in #{last4}" if last4
    description_text = "••••#{last4}"

    description = content_tag :span, description_text, class: 'ml1'
    icon = inline_icon icon_name, width: 40, height: 24, class: 'slate'
    return content_tag(:span,
      class: 'inline-flex items-center  tooltipped tooltipped--e',
      'aria-label': tooltip
    ) {
      icon + description
    }
  else
    icon_name = 'bank-account'
    size = 20
    description_text = invoice.payment_method_type.humanize
  end

  description = content_tag :span, description_text, class: 'ml1'
  icon = inline_icon icon_name, width: size, height: size, class: 'slate'
  content_tag(:span, class: 'inline-flex items-center') { icon + description }
end

def invoice_card_country_mention(invoice = @invoice)
  country_code = invoice&.payment_method_card_country

  return nil unless country_code
  
  # Hack to turn country code into the country's flag
  # https://stackoverflow.com/a/50859942
  emoji = country_code.tr('A-Z', "\u{1F1E6}-\u{1F1FF}")

  content_tag :span, emoji, class: 'tooltipped tooltipped--w pr1', 'aria-label': country_code
end

def invoice_card_check_badge(check, invoice = @invoice)
  case invoice["payment_method_card_checks_#{check}_check"]
  when 'pass'
    background = 'success'
    icon_name = 'checkmark'
    text = 'Passed'
  when 'failed'
    background = 'warning'
    icon_name = 'view-close'
    text = 'Failed'
  when 'unchecked'
    background = 'info'
    icon_name = 'checkbox'
    text = 'Unchecked'
  else
    background = 'smoke'
    icon_name = 'checkbox'
    text = 'Unavailable'
  end

  tag = inline_icon icon_name, size: 24
  content_tag(:span, class: "pr1 #{background} line-height-0 tooltipped tooltipped--w", 'aria-label': text) { tag }
end

def invoice_payout_datetime(invoice = @invoice)
  if @payout_t && @refund_t
    title = 'Funds available since'
    datetime = [@payout_t.created_at, @refund_t.created_at].max
  elsif @payout_t && !@refund
    title = 'Funds available since'
    datetime = @payout_t.created_at
  elsif @invoice.payout_creation_queued_at && @invoice.payout.nil?
    title = 'Transfer scheduled'
    datetime = @invoice.payout_creation_queued_for
  elsif @invoice.payout_creation_queued_at && @invoice.payout.present?
    title = 'Funds should be available'
    datetime = @invoice.payout.arrival_date
  else
    return
  end

  strong_tag = content_tag :strong, title
  date_tag = format_datetime datetime

  content_tag(:p) { strong_tag + date_tag }
end

def invoice_fee_type(invoice = @invoice)
  if @invoice.payment_method_type == 'card'
    brand = @invoice.payment_method_card_brand.humanize.capitalize
    funding = @invoice.payment_method_card_funding.humanize.downcase
    return "#{brand} #{funding} card fee"
  elsif @invoice.payment_method_type == 'ach_credit_transfer'
    'ACH / wire fee'
  else
    'Transfer fee'
  end
end

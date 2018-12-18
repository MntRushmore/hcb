class SyncEmburseTransactionsJob < ApplicationJob
  RUN_EVERY = 5.minutes

  def perform(repeat = false)
    ActiveRecord::Base.transaction do

    # When Emburse gets a 'test' transaction (ie. AWS charges a card to make
    # sure it's valid, but removes the charge later), it will later remove the
    # transaction from their API. We want to archive any transactions that are
    # no longer on Emburse or we'll end up with a bunch of garbage transaction
    # data showing up for our users.
    deleted_transactions = EmburseTransaction.all.pluck :emburse_id

      EmburseClient::Transaction.list.each do |trn|
        deleted_transactions.delete(trn[:id])

        et = EmburseTransaction.find_by(emburse_id: trn[:id])
        et ||= EmburseTransaction.new(emburse_id: trn[:id])

        # Emburse transactions will sometimes post as $0 & update to their correct value later.
        # We want to skip over them until they settle on their correct amount
        next if trn[:amount] === 0

        department_id = trn.dig(:department, :id)
        card = Card.find_by(emburse_id: trn.dig(:card, :id))
        # If the transaction isn't assigned to a department directly, we'll use the card's department
        department_id = card.department_id if department_id.nil? and card

        amount = trn[:amount] * 100
        related_event = department_id ? Event.find_by(emburse_department_id: department_id) : nil

        et.update!(
          amount: amount,
          state: trn[:state],
          emburse_department_id: department_id,
          event: related_event || et.event,
          emburse_card_id: trn.dig(:card, :id),
          card: card,
          merchant_mid: trn.dig(:merchant, :mid),
          merchant_mcc: trn.dig(:merchant, :mcc),
          merchant_name: trn.dig(:merchant, :name),
          merchant_address: trn.dig(:merchant, :address),
          merchant_city: trn.dig(:merchant, :city),
          merchant_state: trn.dig(:merchant, :state),
          merchant_zip: trn.dig(:merchant, :zip),
          category_emburse_id: trn.dig(:category, :id),
          category_url: trn.dig(:category, :url),
          category_code: trn.dig(:category, :code),
          category_name: trn.dig(:category, :name),
          category_parent: trn.dig(:category, :parent),
          label: trn[:label],
          location: trn[:location],
          note: trn[:note],
          receipt_url: trn.dig(:receipt, :url),
          receipt_filename: trn.dig(:receipt, :filename),
          transaction_time: trn[:time]
        )

        self.notify_admin(et) if department_id.nil?
      end

    deleted_transactions.each { |emburse_id| EmburseTransaction.find_by(emburse_id: emburse_id).destroy }
    end

    self.class.set(wait: RUN_EVERY).perform_later(true) if repeat
  end

  def notify_admin(emburse_t)
    return if emburse_t.notified_admin_at

    EmburseTransactionsMailer.notify(emburse_transaction: emburse_t).deliver_later
    emburse_t.update!(notified_admin_at: Time.now)
  end

end

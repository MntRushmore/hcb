# frozen_string_literal: true

module Reimbursement
  module PayoutHoldingService
    class Nightly
      def run
        clearinghouse = Event.find_by(id: EventMappingEngine::EventIds::REIMBURSEMENT_CLEARING)
        Reimbursement::PayoutHolding.settled.find_each(batch_size: 100) do |payout_holding|
          case payout_holding.report.user.payout_method
          when User::PayoutMethod::Check
            Rails.error.handle do
              check = clearinghouse.increase_checks.build(
                memo: "Reimbursement for #{payout_holding.report.name}."[0...40],
                amount: payout_holding.amount_cents,
                payment_for: "Reimbursement for #{payout_holding.report.name}.",
                recipient_name: payout_holding.report.user.full_name,
                address_line1: payout_holding.report.user.payout_method.address_line1,
                address_line2: payout_holding.report.user.payout_method.address_line2,
                address_city: payout_holding.report.user.payout_method.address_city,
                address_state: payout_holding.report.user.payout_method.address_state,
                recipient_email: payout_holding.report.user.email,
                send_email_notification: false,
                address_zip: payout_holding.report.user.payout_method.address_postal_code,
                user: User.find_by(email: "bank@hackclub.com")
              )
              check.save!
              check.send_check!
              payout_holding.increase_check = check
              payout_holding.save!
              payout_holding.mark_sent!
            end
          when User::PayoutMethod::AchTransfer
            Rails.error.handle do
              ach_transfer = clearinghouse.ach_transfers.build(
                amount: payout_holding.amount_cents,
                payment_for: "Reimbursement for #{payout_holding.report.name}.",
                recipient_name: payout_holding.report.user.full_name,
                recipient_email: payout_holding.report.user.email,
                send_email_notification: false,
                routing_number: payout_holding.report.user.payout_method.routing_number,
                account_number: payout_holding.report.user.payout_method.account_number,
                bank_name: (ColumnService.get("/institutions/#{payout_holding.report.user.payout_method.routing_number}")["full_name"] rescue "Bank Account"),
                creator: User.find_by(email: "bank@hackclub.com"),
                company_name: payout_holding.report.event.short_name,
                company_entry_description: "REIMBURSE"
              )
              ach_transfer.save!
              begin
                ach_transfer.approve!(User.find_by(email: "bank@hackclub.com"))
              rescue
                ach_transfer.mark_rejected!(User.find_by(email: "bank@hackclub.com"))
                payout_holding.mark_failed!
                ReimbursementMailer.with(
                  reimbursement_payout_holding: payout_holding,
                  reason: "Your routing number / account number was invalid."
                ).ach_failed.deliver_later
              else
                payout_holding.ach_transfer = ach_transfer
                payout_holding.save!
                payout_holding.mark_sent!
              end
            end
          when User::PayoutMethod::PaypalTransfer
            Rails.error.handle do
              paypal_transfer = clearinghouse.paypal_transfers.build(
                amount_cents: payout_holding.amount_cents,
                payment_for: "Reimbursement for #{payout_holding.report.name}.",
                memo: "Reimbursement for #{payout_holding.report.name}.",
                recipient_email: payout_holding.report.user.payout_method.recipient_email,
                recipient_name: payout_holding.report.user.name,
                user: User.find_by(email: "bank@hackclub.com")
              )
              paypal_transfer.save!
              payout_holding.paypal_transfer = paypal_transfer
              payout_holding.save!
              payout_holding.mark_sent!
            end
          else
            raise ArgumentError, "🚨⚠️ unsupported payout method!"
          end

        end
      end

    end
  end
end

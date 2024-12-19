# frozen_string_literal: true

# == Schema Information
#
# Table name: metrics
#
#  id           :bigint           not null, primary key
#  metric       :jsonb
#  subject_type :string
#  type         :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  subject_id   :bigint
#
# Indexes
#
#  index_metrics_on_subject  (subject_type,subject_id)
#
class Metric
  module Hcb
    class TotalRaised < Metric
      include AppWide

      def calculate
        result = ActiveRecord::Base.connection.execute(<<~SQL)
          SELECT SUM(amount_cents) / 100 as amount FROM "canonical_transactions"
          LEFT JOIN "canonical_event_mappings" ON canonical_transactions.id = canonical_event_mappings.canonical_transaction_id
          LEFT JOIN "events" ON canonical_event_mappings.event_id = events.id
          LEFT JOIN "event_plans" ON event_plans.event_id = events.id AND event_plans.aasm_state = 'active'
          LEFT JOIN "disbursements" ON canonical_transactions.hcb_code = CONCAT('HCB-500-', disbursements.id)
          WHERE amount_cents > 0
          AND date_part('year', date) = date_part('year', now())
          AND event_plans.type != 'Event::Plan::HackClubAffiliate'
          AND event_plans.type != 'Event::Plan::Internal'
          AND event_plans.type != 'Event::Plan::CardsOnly'
          AND event_plans.type != 'Event::Plan::SalaryAccount'
          AND (disbursements.id IS NULL or disbursements.should_charge_fee = true)
          AND NOT (
            canonical_transactions.hcb_code ILIKE 'HCB-300%' OR
            canonical_transactions.hcb_code ILIKE 'HCB-310%' OR
            canonical_transactions.hcb_code ILIKE 'HCB-350%' OR
            canonical_transactions.hcb_code ILIKE 'HCB-400%' OR
            canonical_transactions.hcb_code ILIKE 'HCB-401%' OR
            canonical_transactions.hcb_code ILIKE 'HCB-600%' OR
            canonical_transactions.hcb_code ILIKE 'HCB-601%' OR
            canonical_transactions.hcb_code ILIKE 'HCB-710%' OR
            canonical_transactions.hcb_code ILIKE 'HCB-712%'
          )
        SQL

        result.first["amount"]
      end

    end
  end

end

module RawPlaidTransactionService
  module Likely
    class Disbursement
      def run
        ::RawPlaidTransaction.where("plaid_transaction->>'name' ilike '%hcb disburse%'")
      end
    end
  end
end

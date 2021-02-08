module PendingTransactionEngine
  class Nightly
    def run
      # 1 raw imports
      import_raw_pending_outgoing_check_transactions!
      # import_raw_pending_stripe_transactions!

      # 2 canonical
      canonize_raw_pending_outgoing_check_transactions!
      # canonize_raw_pending_stripe_transactions!
    end

    private

    def import_raw_pending_outgoing_check_transactions!
      ::PendingTransactionEngine::RawPendingOutgoingCheckTransactionService::Lob::Import.new.run
    end

    def canonize_raw_pending_outgoing_check_transactions!
      ::PendingTransactionEngine::CanonicalPendingTransactionService::Import::OutgoingCheck.new.run
    end

    def import_raw_pending_stripe_transactions!
      #::PendingTransactionEngine::RawPendingStripeTransactionService::Stripe::Import.new.run
    end

    def canonize_raw_pending_stripe_transactions!
      #::PendingTransactionEngine::CanonicalPendingTransactionService::Import::All.new.run
    end
  end
end

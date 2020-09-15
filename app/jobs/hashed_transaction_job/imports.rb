# frozen_string_literal: true

module HashedTransactionJob
  class Imports < ApplicationJob
    def perform
      ::HashedTransactionService::RawPlaidTransaction::Import.new.run
    end
  end
end

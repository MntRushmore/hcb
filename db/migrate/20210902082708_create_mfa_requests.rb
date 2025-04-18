# frozen_string_literal: true

class CreateMfaRequests < ActiveRecord::Migration[6.0]
  def change
    create_table :mfa_requests do |t|
      t.string :provider
      t.references :mfa_code, foreign_key: true
      t.string :aasm_state

      t.timestamps
    end
  end

end

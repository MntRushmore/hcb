# frozen_string_literal: true

json.partial! @stripe_card, expand: [:user, :organization]

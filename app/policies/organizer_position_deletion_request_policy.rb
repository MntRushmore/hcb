# frozen_string_literal: true

class OrganizerPositionDeletionRequestPolicy < ApplicationPolicy
  def index?
    user.admin?
  end

  def new?
    create?
  end

  def create?
    event = record.organizer_position.event

    target_is_in_event = event.organizer_positions.include?(record.organizer_position)
    target_has_no_pending_request = record.organizer_position.organizer_position_deletion_requests.under_review.none?

    user.admin? || (target_is_in_event && target_has_no_pending_request && current_user_is_manager?)
  end

  def show?
    user.admin?
  end

  def close?
    user.admin?
  end

  def open?
    user.admin?
  end

  private

  def event
    record.organizer_position.event
  end

  def user_in_event?
    event.users.include? user
  end

  def current_user_is_manager?
    OrganizerPosition.find_by(user:, event: record.event)&.manager?
  end

end

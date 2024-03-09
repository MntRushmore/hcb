# frozen_string_literal: true

class OrganizerPositionMailer < ApplicationMailer
  def role_change
    @position = params[:organizer_position]
    @previous_role = params[:previous_role]
    @changer = params[:changer]

    mail to: @position.user.email, subject: "Your role in #{@position.event.name} has been changed on HCB 🗣️‼️"
  end

end

# frozen_string_literal: true

class TwilioController < ActionController::Base
  protect_from_forgery except: :webhook
  before_action :set_attachments, :set_user

  def webhook
    return reply_with(<<~MSG.squish) if @user.nil?
      Hey! We couldn't find your account on HCB; if you're looking to upload
      receipts, make sure your phone number is set and verified in your account's settings
      (https://hcb.hackclub.com/my/settings).
    MSG

    return reply_with(<<~MSG.squish) unless Flipper.enabled?(:receipt_bin_2023_04_07, @user)
      Hey! Looking to upload receipts? Make sure the Receipt Bin feature preview
      is enabled on your account (https://hcb.hackclub.com/my/settings/previews).
    MSG

    return reply_with(<<~MSG.squish) if @attachments.none?
      Hey! Are you trying to upload receipts? We couldn't find any attachments in your message.#{' '}
      If you're looking for HCB support, please reach out to hcb@hackclub.com.
    MSG

    receiptable = nil

    if last_sent_message_hcb_code && last_sent_message_hcb_code.cpt.created_at > 5.mins.ago
      receiptable = last_sent_message_hcb_code
    end

    receipts = ::ReceiptService::Create.new(
      receiptable:,
      uploader: @user,
      attachments: @attachments,
      upload_method: "sms"
    ).run!

    if receiptable
      reply_with("Attached #{receipts.count} #{"receipt".pluralize(receipts.count)} to #{receiptable.memo} (#{hcb_code_url(receiptable)})!")
    else
      reply_with("Added #{receipts.count} #{"receipt".pluralize(receipts.count)} to your Receipt Bin (https://hcb.hackclub.com/my/inbox)!")
    end
  end

  private

  def reply_with(message)
    respond_to do |format|
      format.xml { render xml: "<Response><Message> #{message} </Message></Response>" }
    end
  end

  def set_user
    potential_users = User.where(phone_number: params["From"], phone_number_verified: true)
    return @user = potential_users.first if potential_users.count == 1

    # If we have multiple users with the same phone number, try to find the user via their stripe card
    user_id = last_sent_message_hcb_code&.canonical_pending_transactions&.last&.stripe_card&.user&.id
    @user = potential_users.find_by(id: user_id)
  end

  def set_attachments
    num_media = params["NumMedia"].to_i
    return @attachments = [] if num_media.zero?

    @attachments = (0..num_media - 1).map do |i|
      uri = URI.parse(params["MediaUrl#{i}"])
      break unless uri.scheme == "http" || uri.scheme == "https"

      {
        filename: "SMS_#{Time.now.strftime("%Y-%m-%d-%H:%M")}",
        content_type: params["MediaContentType#{i}"],
        io: uri.open
      }
    end
  end

  def last_sent_message_hcb_code
    @last_sent_message_hcb_code ||= OutgoingTwilioMessage
                                    .joins(:twilio_message)
                                    .where("twilio_messages.to" => params["From"])
                                    .where.not(hcb_code: nil)
                                    .last&.hcb_code
  end

end

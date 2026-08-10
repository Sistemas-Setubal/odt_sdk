# frozen_string_literal: true

module OdtSdk
  class Message
    attr_reader :service_id, :number, :carrier, :message

    def initialize(service_id:, number:, carrier:, message:)
      @service_id = service_id
      @number = number
      @carrier = carrier
      @message = message
    end

    def to_notify
      { service_id: service_id.to_s, number: number.to_s, carrier: carrier.to_s, message: message.to_s }
    end
  end
end

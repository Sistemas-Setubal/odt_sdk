# frozen_string_literal: true

module OdtSdk
  class Client
    SEND_PATH = '/sendsms'

    attr_reader :configuration

    def initialize(configuration, transport: nil)
      @configuration = configuration
      @transport = transport
    end

    def transport
      @transport ||= Transport::HttpParty.new timeout: configuration.timeout
    end

    def send_url
      "#{configuration.base_url.to_s.chomp '/'}#{SEND_PATH}"
    end

    def send_sms(**fields)
      sms = Message.new(**{ service_id: configuration.service_id }.merge(fields))

      request notify: sms.to_notify
    end

    def send_sms!(**fields)
      ensure_sent send_sms(**fields)
    end

    def request(payload)
      reply = transport.post send_url, payload.merge(security: security.build)

      Response.new status: reply[:status], body: reply[:body]
    end

    def request!(payload)
      ensure_sent request(payload)
    end

    private

    def ensure_sent(response)
      raise ApiError, response if response.failure?

      response
    end

    def security
      @security ||= Security.new configuration
    end
  end
end

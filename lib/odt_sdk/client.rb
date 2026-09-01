# frozen_string_literal: true

module OdtSdk
  class Client
    SEND_PATH = '/sendsms'

    BULK_OPTIONS = %i[concurrency throttle dispatcher].freeze

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

    def send_bulk(numbers: nil, recipients: nil, **options)
      batch = Bulk::Batch.new numbers: numbers, recipients: recipients, **options.except(*BULK_OPTIONS)
      pool = Bulk::Pool.new concurrency: options[:concurrency], throttle: options[:throttle]

      warm_shared_state

      Bulk::Runner.new(self, pool: pool, dispatcher: options[:dispatcher]).call batch
    end

    def send_bulk!(**options)
      ensure_delivered send_bulk(**options)
    end

    def request(payload)
      reply = transport.post send_url, payload.merge(security: security.build)

      Response.new status: reply[:status], body: reply[:body]
    end

    def request!(payload)
      ensure_sent request(payload)
    end

    private

    def warm_shared_state
      transport
      security
    end

    def ensure_delivered(result)
      raise BulkError, result if result.failure?

      result
    end

    def ensure_sent(response)
      raise ApiError, response if response.failure?

      response
    end

    def security
      @security ||= Security.new configuration
    end
  end
end

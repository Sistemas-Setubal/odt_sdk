# frozen_string_literal: true

module OdtSdk
  module Bulk
    class Runner
      DELIVERY_ERRORS = [ArgumentError, TransportError].freeze

      attr_reader :client, :pool, :dispatcher

      def initialize(client, pool: Pool.new, dispatcher: nil)
        @client = client
        @pool = pool
        @dispatcher = dispatcher
      end

      def call(batch)
        Result.new pool.map(batch.items) { |item| deliver item }
      end

      private

      def deliver(item)
        return enqueue item if dispatcher

        send_one item
      end

      def send_one(item)
        Delivery.from_response item, client.send_sms(**item)
      rescue *DELIVERY_ERRORS => error
        Delivery.from_error item, error
      end

      def enqueue(item)
        dispatcher.call item

        Delivery.enqueued item
      rescue StandardError => error
        Delivery.from_error item, error
      end
    end
  end
end

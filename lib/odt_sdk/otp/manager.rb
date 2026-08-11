# frozen_string_literal: true

module OdtSdk
  module Otp
    class Manager
      attr_reader :client

      def initialize(client, **options)
        @client = client
        @options = options
      end

      def store
        @options[:store] ||= MemoryStore.new
      end

      def template
        @options[:template] ||= Template.new
      end

      def length
        @options.fetch :length, Generator::DEFAULT_LENGTH
      end

      def ttl
        @options.fetch :ttl, MemoryStore::DEFAULT_TTL
      end

      def send_code(number:, carrier:, **fields)
        reject_body_override fields

        code = Generator.numeric length
        store.write number, code, ttl: ttl

        deliver number: number, carrier: carrier, message: template.render(code), **fields
      rescue ArgumentError
        store.delete number
        raise
      end

      private

      def deliver(**fields)
        client.send_sms(**{ encode: template.encoding }.merge(fields))
      end

      def reject_body_override(fields)
        return unless fields.key? :message

        raise ArgumentError, 'send_code writes the message from the template. Pass template: instead.'
      end
    end
  end
end

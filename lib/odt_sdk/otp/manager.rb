# frozen_string_literal: true

module OdtSdk
  module Otp
    class Manager
      DEFAULT_MAX_ATTEMPTS = 3

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

      def max_attempts
        limit = @options.fetch :max_attempts, DEFAULT_MAX_ATTEMPTS

        return limit if limit.is_a?(Integer) && limit.positive?

        raise ArgumentError, "Invalid max_attempts #{limit.inspect}. Use a positive integer."
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

      def verify(number:, code:)
        entry = store.read number

        return Result.new :not_found if entry.nil?
        return Result.new :expired if entry.expired?
        return Result.new :too_many_attempts if entry.attempts >= max_attempts

        return consume number if Security.secure_compare entry.code, code

        store.increment_attempts number

        Result.new :mismatch
      end

      def valid?(number:, code:)
        verify(number: number, code: code).ok?
      end

      private

      def consume(number)
        store.delete number

        Result.new :ok
      end

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

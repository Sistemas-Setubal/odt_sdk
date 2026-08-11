# frozen_string_literal: true

module OdtSdk
  module Otp
    class Entry
      attr_reader :code, :expires_at, :attempts

      def initialize(code:, expires_at:, attempts: 0)
        @code = code
        @expires_at = expires_at
        @attempts = attempts
      end

      def expired?
        Time.now >= expires_at
      end

      def with_attempt
        self.class.new code: code, expires_at: expires_at, attempts: attempts + 1
      end
    end
  end
end

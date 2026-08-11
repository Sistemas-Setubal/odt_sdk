# frozen_string_literal: true

require 'securerandom'

module OdtSdk
  module Otp
    module Generator
      DEFAULT_LENGTH = 4

      def self.numeric(length = DEFAULT_LENGTH)
        validate_length length

        SecureRandom.random_number(10**length).to_s.rjust length, '0'
      end

      def self.validate_length(length)
        return if length.is_a?(Integer) && length.positive?

        raise ArgumentError, "Invalid OTP length #{length.inspect}. Use a positive integer."
      end

      private_class_method :validate_length
    end
  end
end

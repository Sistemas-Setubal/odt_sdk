# frozen_string_literal: true

module OdtSdk
  module Otp
    class Result
      REASONS = %i[ok mismatch expired too_many_attempts not_found].freeze

      attr_reader :reason

      def initialize(reason)
        demand_known reason

        @reason = reason
      end

      def ok?
        reason == :ok
      end

      private

      def demand_known(reason)
        return if REASONS.include? reason

        raise ArgumentError, "Unknown verification reason #{reason.inspect}. Valid: #{REASONS.join ', '}."
      end
    end
  end
end

# frozen_string_literal: true

module OdtSdk
  module Bulk
    class Result
      include Enumerable

      attr_reader :deliveries

      def initialize(deliveries)
        @deliveries = deliveries
      end

      def each(&)
        deliveries.each(&)
      end

      def size
        deliveries.size
      end

      def successes
        deliveries.select(&:success?)
      end

      def failures
        deliveries.select(&:failure?)
      end

      def retryable
        deliveries.select(&:retryable?)
      end

      def enqueued
        deliveries.select(&:enqueued?)
      end

      def success?
        failures.empty?
      end

      def failure?
        !success?
      end

      def numbers
        deliveries.map { |delivery| delivery.number.to_s }
      end

      def to_h
        { total: size, successes: successes.size, failures: failures.size,
          deliveries: deliveries.map(&:to_h) }
      end
    end
  end
end

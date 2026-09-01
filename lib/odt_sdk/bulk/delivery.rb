# frozen_string_literal: true

module OdtSdk
  module Bulk
    class Delivery
      STATUSES = %i[success queued temporary_failure malformed unknown
                    invalid transport_error error enqueued].freeze

      RETRYABLE_STATUSES = %i[temporary_failure transport_error].freeze

      def self.from_response(item, response)
        new item: item, status: response.status, response: response
      end

      def self.from_error(item, error)
        new item: item, status: status_for(error), error: error
      end

      def self.enqueued(item)
        new item: item, status: :enqueued
      end

      def self.status_for(error)
        return :invalid if error.is_a? ArgumentError
        return :transport_error if error.is_a? TransportError

        :error
      end

      attr_reader :item, :status, :response, :error

      def initialize(item:, status:, response: nil, error: nil)
        demand_known status

        @item = item
        @status = status
        @response = response
        @error = error
      end

      def number
        item[:number]
      end

      def success?
        status == :success
      end

      def enqueued?
        status == :enqueued
      end

      def failure?
        !success? && !enqueued?
      end

      def retryable?
        RETRYABLE_STATUSES.include? status
      end

      def reason
        return error.message if error
        return response.message if response

        nil
      end

      def to_h
        { number: number.to_s, status: status, reason: reason }.compact
      end

      private

      def demand_known(status)
        return if STATUSES.include? status

        raise ArgumentError, "Unknown delivery status #{status.inspect}. Valid: #{STATUSES.join ', '}."
      end
    end
  end
end

# frozen_string_literal: true

module OdtSdk
  module Bulk
    class Batch
      include Enumerable

      SOURCE_REQUIRED = 'A bulk batch needs numbers: with shared fields, or recipients: with one hash per number.'

      def initialize(numbers: nil, recipients: nil, **shared)
        @numbers = numbers
        @recipients = recipients
        @shared = shared

        demand_single_source
      end

      def items
        @items ||= expand.uniq { |item| item[:number].to_s }
      end

      def each(&)
        items.each(&)
      end

      def size
        items.size
      end

      private

      def expand
        return @recipients.map { |recipient| @shared.merge normalize(recipient) } if @recipients

        @numbers.map { |number| @shared.merge number: number }
      end

      def normalize(recipient)
        raise ArgumentError, "Each recipient must be a Hash, got #{recipient.inspect}." unless recipient.is_a? Hash

        recipient.transform_keys(&:to_sym)
      end

      def demand_single_source
        source = single_source

        raise ArgumentError, SOURCE_REQUIRED unless source.is_a? Array
        raise ArgumentError, 'A bulk batch needs at least one recipient.' if source.empty?
      end

      def single_source
        given = [@numbers, @recipients].compact

        raise ArgumentError, SOURCE_REQUIRED unless given.size == 1

        given.first
      end
    end
  end
end

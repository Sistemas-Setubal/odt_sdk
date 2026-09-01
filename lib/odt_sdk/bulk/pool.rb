# frozen_string_literal: true

module OdtSdk
  module Bulk
    class Pool
      DEFAULT_CONCURRENCY = 1

      def self.normalize_concurrency(value)
        return DEFAULT_CONCURRENCY if value.nil?

        workers = Integer value.to_s, 10, exception: false

        return workers if workers&.positive?

        raise ArgumentError, "Invalid concurrency #{value.inspect}. Use a positive integer."
      end

      def self.normalize_throttle(value)
        return nil if value.nil?

        seconds = Float value.to_s, exception: false

        return seconds unless seconds.nil? || seconds.negative?

        raise ArgumentError, "Invalid throttle #{value.inspect}. Use a number of seconds."
      end

      attr_reader :workers, :throttle

      def initialize(concurrency: nil, throttle: nil)
        settings = self.class

        @workers = settings.normalize_concurrency concurrency
        @throttle = settings.normalize_throttle throttle
      end

      def map(items, &)
        return items.map { |item| run item, & } if workers == 1

        concurrent items, &
      end

      private

      def run(item)
        outcome = yield item

        pause

        outcome
      end

      def pause
        return if throttle.nil?

        sleep throttle
      end

      def concurrent(items, &)
        queue = Queue.new
        results = Array.new items.size

        items.each_with_index { |item, index| queue << [index, item] }
        workers.times { queue << nil }

        Array.new(workers) { worker queue, results, & }.each(&:join)

        results
      end

      def worker(queue, results, &)
        Thread.new do
          while (entry = queue.pop)
            index, item = entry
            results[index] = run item, &
          end
        end
      end
    end
  end
end

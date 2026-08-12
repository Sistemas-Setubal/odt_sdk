# frozen_string_literal: true

module OdtSdk
  module Otp
    class MemoryStore
      DEFAULT_TTL = 300
      PURGE_AFTER = 3600

      def initialize
        @entries = {}
        @sends = {}
        @mutex = Mutex.new
      end

      def write(key, code, ttl: DEFAULT_TTL)
        validate_ttl ttl

        entry = Entry.new code: code, expires_at: Time.now + ttl

        @mutex.synchronize do
          purge_stale
          @entries[key.to_s] = entry
        end
      end

      def read(key)
        @mutex.synchronize { @entries[key.to_s] }
      end

      def matches?(key, code)
        entry = read key

        return false if entry.nil?

        Security.secure_compare entry.code, code
      end

      def increment_attempts(key)
        id = key.to_s

        @mutex.synchronize do
          entry = @entries[id]

          next if entry.nil?

          @entries[id] = entry.with_attempt
        end
      end

      def delete(key)
        @mutex.synchronize { @entries.delete key.to_s }
      end

      def record_send(key, window:)
        @mutex.synchronize do
          bucket = bucket_for key.to_s, window
          count = bucket.fetch(:count) + 1
          bucket[:count] = count

          count
        end
      end

      private

      def bucket_for(id, window)
        now = Time.now
        bucket = @sends[id]

        return bucket if bucket && now < bucket.fetch(:resets_at)

        @sends[id] = { count: 0, resets_at: now + window }
      end

      def validate_ttl(ttl)
        return if ttl.is_a?(Numeric) && ttl.positive?

        raise ArgumentError, "Invalid TTL #{ttl.inspect}. Use a positive number of seconds."
      end

      def purge_stale
        cutoff = Time.now - PURGE_AFTER

        @entries.delete_if { |_key, entry| entry.expires_at < cutoff }
      end
    end
  end
end

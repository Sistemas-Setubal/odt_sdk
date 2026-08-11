# frozen_string_literal: true

module OdtSdk
  module Otp
    class MemoryStore
      DEFAULT_TTL = 300
      PURGE_AFTER = 3600

      def initialize
        @entries = {}
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

      private

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

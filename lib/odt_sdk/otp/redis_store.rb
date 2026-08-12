# frozen_string_literal: true

require 'openssl'
require 'securerandom'

module OdtSdk
  module Otp
    class RedisStore
      DEFAULT_TTL = 300
      GRACE = 3600
      NAMESPACE = 'odt_sdk:otp'

      attr_reader :redis, :namespace, :pepper

      def initialize(redis, namespace: NAMESPACE, pepper: nil)
        @redis = redis
        @namespace = namespace
        @pepper = pepper
      end

      def write(key, code, ttl: DEFAULT_TTL)
        validate_ttl ttl

        salt = SecureRandom.hex 16
        fields = { 'digest' => fingerprint(code, salt), 'salt' => salt,
                   'expires_at' => (Time.now + ttl).to_r.to_s, 'attempts' => '0' }

        store_fields key_for(key), fields, ttl
      end

      def matches?(key, code)
        fields = redis.hgetall key_for(key)

        return false if fields.empty?

        Security.secure_compare fields['digest'], fingerprint(code, fields['salt'])
      end

      def read(key)
        entry_from redis.hgetall(key_for(key))
      end

      def increment_attempts(key)
        id = key_for key

        redis.hincrby id, 'attempts', 1 if redis.exists? id
      end

      def delete(key)
        redis.del key_for(key)
      end

      def record_send(key, window:)
        id = "#{key_for key}:sends"
        count = redis.incr id

        redis.expire id, window.to_i if count == 1

        count
      end

      private

      def store_fields(id, fields, ttl)
        redis.multi do |tx|
          tx.del id
          tx.hset id, fields
          tx.expire id, (ttl + GRACE).to_i
        end
      end

      def fingerprint(code, salt)
        OpenSSL::HMAC.hexdigest 'SHA256', "#{pepper}#{salt}", code.to_s
      end

      def key_for(key)
        "#{namespace}:#{key}"
      end

      def entry_from(fields)
        return nil if fields.nil? || fields.empty?

        Entry.new code: nil,
                  expires_at: Time.at(Rational(fields['expires_at'])),
                  attempts: fields['attempts'].to_i
      end

      def validate_ttl(ttl)
        return if ttl.is_a?(Numeric) && ttl.positive?

        raise ArgumentError, "Invalid TTL #{ttl.inspect}. Use a positive number of seconds."
      end
    end
  end
end

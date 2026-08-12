# frozen_string_literal: true

require 'digest'
require 'openssl'

module OdtSdk
  class Security
    TIMESTAMP_FORMATS = { milliseconds: '%s%L', seconds: '%s' }.freeze

    def self.timestamp(unit = Configuration::DEFAULT_TIMESTAMP_UNIT)
      format = TIMESTAMP_FORMATS.fetch Configuration.normalize_timestamp_unit(unit)

      Time.now.strftime format
    end

    def self.hash_for(partner_id:, time:, secure_key:)
      Digest::MD5.hexdigest "#{partner_id}#{time}#{secure_key}"
    end

    def self.secure_compare(left, right)
      OpenSSL.fixed_length_secure_compare Digest::SHA256.digest(left.to_s),
                                          Digest::SHA256.digest(right.to_s)
    end

    attr_reader :configuration

    def initialize(configuration)
      @configuration = configuration
    end

    def build(time: nil)
      configuration.validate!

      stamp = timestamp_for time

      { partner_id: configuration.partner_id, time: stamp, hash: digest_for(stamp) }
    end

    private

    def digest_for(time)
      self.class.hash_for partner_id: configuration.partner_id,
                          time: time,
                          secure_key: configuration.secure_key
    end

    def timestamp_for(time)
      return time.to_s unless time.nil?

      self.class.timestamp configuration.timestamp_unit
    end
  end
end

# frozen_string_literal: true

module OdtSdk
  class Message
    REQUIRED_FIELDS = %i[service_id number carrier message].freeze
    FIELDS = (REQUIRED_FIELDS + %i[encode]).freeze

    NUMBER_FORMAT = /\A\d{10}\z/

    UNSUPPORTED_CHARACTERS = 'message carries characters this encoding replaces. ' \
                     'Write it without accents, or send it with Encodings::UCS2.'

    def initialize(**fields)
      @fields = fields

      validate_keys
    end

    def service_id
      @fields[:service_id]
    end

    def number
      @fields[:number]
    end

    def carrier
      @fields[:carrier]
    end

    def message
      @fields[:message]
    end

    def encode
      @fields[:encode]
    end

    def validate
      validation_error.nil?
    end

    def validate!
      error = validation_error

      raise ArgumentError, error if error

      self
    end

    def to_notify
      validate!

      { service_id: service_id.to_s, number: number.to_s, carrier: carrier.to_s,
        message: message.to_s, encode: encode&.to_s }.compact
    end

    private

    def validate_keys
      given = @fields.keys
      unknown = given - FIELDS

      raise ArgumentError, "unknown keyword: #{unknown.join ', '}" unless unknown.empty?

      missing = REQUIRED_FIELDS - given

      raise ArgumentError, "missing keyword: #{missing.join ', '}" unless missing.empty?
    end

    def validation_error
      return 'service_id is required.' if service_id.to_s.strip.empty?
      return 'message cannot be empty.' if message.to_s.strip.empty?

      invalid_value_error
    end

    def invalid_value_error
      return number_error unless number.to_s.match? NUMBER_FORMAT
      return carrier_error unless Carriers.valid? carrier

      encoding_error
    end

    def encoding_error
      return Encodings.invalid_error encode unless encode.nil? || Encodings.valid?(encode)
      return UNSUPPORTED_CHARACTERS unless Encodings.supports? message, encode
      return Encodings.limit_error message, encode unless Encodings.fits? message, encode

      nil
    end

    def number_error
      "Invalid number #{number.inspect}. ODT expects an MSISDN of 10 digits."
    end

    def carrier_error
      "Invalid carrier #{carrier.inspect}. Valid carriers: #{Carriers::ALL.join ', '}."
    end
  end
end

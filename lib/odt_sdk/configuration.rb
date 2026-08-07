# frozen_string_literal: true

module OdtSdk
  class Configuration
    TIMESTAMP_UNITS = %i[milliseconds seconds].freeze
    REQUIRED_SETTINGS = %i[partner_id secure_key].freeze

    DEFAULT_BASE_URL = 'https://smsapi.odt.com.mx'
    DEFAULT_TIMEOUT = 10
    DEFAULT_TIMESTAMP_UNIT = :milliseconds

    def initialize
      @settings = {
        partner_id: nil,
        secure_key: nil,
        service_id: nil,
        base_url: DEFAULT_BASE_URL,
        timeout: DEFAULT_TIMEOUT
      }
      self.timestamp_unit = DEFAULT_TIMESTAMP_UNIT
    end

    def partner_id
      @settings[:partner_id]
    end

    def partner_id=(value)
      @settings[:partner_id] = value
    end

    def secure_key
      @settings[:secure_key]
    end

    def secure_key=(value)
      @settings[:secure_key] = value
    end

    def service_id
      @settings[:service_id]
    end

    def service_id=(value)
      @settings[:service_id] = value
    end

    def base_url
      @settings[:base_url]
    end

    def base_url=(value)
      @settings[:base_url] = value
    end

    def timeout
      @settings[:timeout]
    end

    def timeout=(value)
      @settings[:timeout] = value
    end

    def timestamp_unit
      @settings[:timestamp_unit]
    end

    def timestamp_unit=(value)
      unit = value.to_s.strip.downcase.to_sym

      unless TIMESTAMP_UNITS.include? unit
        raise ConfigurationError,
              "Unknown timestamp unit #{value.inspect}. " \
              "Valid units: #{TIMESTAMP_UNITS.join ', '}."
      end

      @settings[:timestamp_unit] = unit
    end

    def validate
      REQUIRED_SETTINGS.none? { |setting| @settings[setting].to_s.strip.empty? }
    end

    def validate!
      return self if validate

      missing = REQUIRED_SETTINGS.select { |setting| @settings[setting].to_s.strip.empty? }

      raise ConfigurationError,
            "Missing ODT credentials: #{missing.join ', '}. " \
            'Assign them on the configuration before sending requests.'
    end
  end
end

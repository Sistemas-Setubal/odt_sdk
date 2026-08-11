# frozen_string_literal: true

module OdtSdk
  module Encodings
    REPLACING = 0
    GSM = 1
    UCS2 = 2

    LIMITS = { REPLACING => 160, GSM => 160, UCS2 => 70 }.freeze

    ALL = LIMITS.keys.freeze

    def self.normalize(encoding)
      Integer encoding.to_s, 10, exception: false
    end

    def self.valid?(encoding)
      ALL.include? normalize(encoding)
    end

    def self.supports?(text, encoding)
      return true if normalize(encoding) == UCS2

      !text.to_s.match?(/[^\x00-\x7F]/)
    end

    def self.limit(encoding)
      LIMITS.fetch normalize(encoding), LIMITS.fetch(REPLACING)
    end

    def self.fits?(text, encoding)
      text.to_s.length <= limit(encoding)
    end

    def self.invalid_error(encoding)
      "Invalid encode #{encoding.inspect}. Valid encodings: #{ALL.join ', '}."
    end

    def self.limit_error(text, encoding)
      "message is #{text.to_s.length} characters, over the #{limit encoding} " \
        'this encoding allows. Shorten it, and note UCS-2 only allows 70.'
    end
  end
end

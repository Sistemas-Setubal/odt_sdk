# frozen_string_literal: true

module OdtSdk
  module Encodings
    REPLACING = 0
    GSM = 1
    UCS2 = 2

    ALL = [REPLACING, GSM, UCS2].freeze

    NON_ASCII = /[^\x00-\x7F]/

    def self.valid?(encoding)
      ALL.include? Integer(encoding.to_s, 10, exception: false)
    end

    def self.supports?(text, encoding)
      return true if Integer(encoding.to_s, 10, exception: false) == UCS2

      !text.to_s.match?(NON_ASCII)
    end
  end
end

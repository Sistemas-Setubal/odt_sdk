# frozen_string_literal: true

module OdtSdk
  module Encodings
    REPLACING = 0
    GSM = 1
    UCS2 = 2

    ALL = [REPLACING, GSM, UCS2].freeze

    def self.valid?(encoding)
      ALL.include? Integer(encoding.to_s, 10, exception: false)
    end
  end
end

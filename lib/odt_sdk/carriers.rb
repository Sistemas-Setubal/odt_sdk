# frozen_string_literal: true

module OdtSdk
  module Carriers
    DEFAULT = 0
    TELCEL = 1
    MOVISTAR = 2
    ATT = 3

    ALL = [DEFAULT, TELCEL, MOVISTAR, ATT].freeze

    def self.valid?(carrier)
      ALL.include? Integer(carrier.to_s, 10, exception: false)
    end
  end
end

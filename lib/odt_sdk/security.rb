# frozen_string_literal: true

require 'digest'

module OdtSdk
  class Security
    def self.hash_for(partner_id:, time:, secure_key:)
      Digest::MD5.hexdigest "#{partner_id}#{time}#{secure_key}"
    end
  end
end

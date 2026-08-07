# frozen_string_literal: true

require 'odt_sdk'

RSpec.describe OdtSdk::Security do
  describe '.hash_for' do
    subject :hash do
      described_class.hash_for partner_id: 'LOCAL_OTP', time: '1679590064554', secure_key: 'XBYi9RC0'
    end

    it 'matches the known ODT sandbox hash' do
      expect(hash).to eq('6ecc4ceeb3f9bb092c78b75beb97983d')
    end

    it 'returns a lowercase hex digest' do
      expect(hash).to match(/\A[0-9a-f]{32}\z/)
    end

    it 'concatenates partner_id, time and secure_key in that order' do
      swapped = described_class.hash_for partner_id: 'XBYi9RC0', time: '1679590064554', secure_key: 'LOCAL_OTP'

      expect(hash).not_to eq(swapped)
    end

    it 'digests a numeric time as its string form' do
      numeric = described_class.hash_for partner_id: 'LOCAL_OTP', time: 1_679_590_064_554, secure_key: 'XBYi9RC0'

      expect(numeric).to eq(hash)
    end

    it 'changes when the time changes' do
      later = described_class.hash_for partner_id: 'LOCAL_OTP', time: '1679590064555', secure_key: 'XBYi9RC0'

      expect(later).not_to eq(hash)
    end

    it 'changes when the secure_key changes' do
      other = described_class.hash_for partner_id: 'LOCAL_OTP', time: '1679590064554', secure_key: 'XBYi9RC1'

      expect(other).not_to eq(hash)
    end
  end
end

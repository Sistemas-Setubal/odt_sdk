# frozen_string_literal: true

require 'odt_sdk'

RSpec.describe OdtSdk::Otp::Entry do
  subject(:entry) { described_class.new code: '0473', expires_at: Time.now + 300 }

  describe 'accessors' do
    it 'reads the code' do
      expect(entry.code).to eq('0473')
    end

    it 'starts with no attempts spent' do
      expect(entry.attempts).to eq(0)
    end

    it 'accepts a starting attempt count' do
      expect(described_class.new(code: '0473', expires_at: Time.now, attempts: 2).attempts).to eq(2)
    end
  end

  describe '#expired?' do
    it 'is false before the expiry' do
      expect(described_class.new(code: '0473', expires_at: Time.now + 60)).not_to be_expired
    end

    it 'is true after the expiry' do
      expect(described_class.new(code: '0473', expires_at: Time.now - 1)).to be_expired
    end
  end

  describe '#with_attempt' do
    it 'counts one more attempt' do
      expect(entry.with_attempt.attempts).to eq(1)
    end

    it 'carries the code over' do
      expect(entry.with_attempt.code).to eq('0473')
    end

    it 'carries the expiry over' do
      expect(entry.with_attempt.expires_at).to eq(entry.expires_at)
    end

    it 'leaves the original untouched' do
      entry.with_attempt

      expect(entry.attempts).to eq(0)
    end
  end
end

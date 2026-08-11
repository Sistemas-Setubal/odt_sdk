# frozen_string_literal: true

require 'odt_sdk'

RSpec.describe OdtSdk::Otp::Result do
  describe '#ok?' do
    it 'is true only for ok' do
      expect(described_class.new(:ok)).to be_ok
    end

    it 'is false for a mismatch' do
      expect(described_class.new(:mismatch)).not_to be_ok
    end

    it 'is false for an expired code' do
      expect(described_class.new(:expired)).not_to be_ok
    end

    it 'is false for too many attempts' do
      expect(described_class.new(:too_many_attempts)).not_to be_ok
    end

    it 'is false when nothing was stored' do
      expect(described_class.new(:not_found)).not_to be_ok
    end
  end

  describe '#reason' do
    it 'keeps the reason it was given' do
      expect(described_class.new(:expired).reason).to eq(:expired)
    end
  end

  describe 'unknown reasons' do
    it 'are refused, so a typo cannot read as not ok' do
      expect { described_class.new :expried }.to raise_error(ArgumentError, /expried/)
    end

    it 'name the valid reasons' do
      expect { described_class.new :nope }.to raise_error(ArgumentError, /ok, mismatch, expired/)
    end
  end
end

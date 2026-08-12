# frozen_string_literal: true

require 'odt_sdk'

RSpec.describe OdtSdk::Carriers do
  describe 'constants' do
    it 'numbers the default carrier' do
      expect(described_class::DEFAULT).to eq(0)
    end

    it 'numbers Telcel' do
      expect(described_class::TELCEL).to eq(1)
    end

    it 'numbers Movistar' do
      expect(described_class::MOVISTAR).to eq(2)
    end

    it 'numbers AT&T' do
      expect(described_class::ATT).to eq(3)
    end

    it 'lists every carrier ODT documents' do
      expect(described_class::ALL).to eq([0, 1, 2, 3])
    end

    it 'freezes the list' do
      expect(described_class::ALL).to be_frozen
    end
  end

  describe '.valid?' do
    it 'accepts a documented carrier' do
      expect(described_class).to be_valid(described_class::TELCEL)
    end

    it 'accepts the default carrier' do
      expect(described_class).to be_valid(0)
    end

    it 'accepts a carrier written as a string' do
      expect(described_class).to be_valid('3')
    end

    it 'rejects a carrier ODT does not define' do
      expect(described_class).not_to be_valid(4)
    end

    it 'rejects a negative carrier' do
      expect(described_class).not_to be_valid(-1)
    end

    it 'rejects a word' do
      expect(described_class).not_to be_valid('telcel')
    end

    it 'rejects nil' do
      expect(described_class).not_to be_valid(nil)
    end

    it 'rejects an empty string' do
      expect(described_class).not_to be_valid('')
    end

    it 'reads a leading zero as base ten' do
      expect(described_class).not_to be_valid('010')
    end
  end
end

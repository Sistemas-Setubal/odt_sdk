# frozen_string_literal: true

require 'odt_sdk'

RSpec.describe OdtSdk::Encodings do
  describe 'constants' do
    it 'numbers the replacing encoding ODT defaults to' do
      expect(described_class::REPLACING).to eq(0)
    end

    it 'numbers strict GSM' do
      expect(described_class::GSM).to eq(1)
    end

    it 'numbers UCS-2' do
      expect(described_class::UCS2).to eq(2)
    end

    it 'lists every encoding ODT documents' do
      expect(described_class::ALL).to eq([0, 1, 2])
    end

    it 'freezes the list' do
      expect(described_class::ALL).to be_frozen
    end
  end

  describe '.valid?' do
    it 'accepts the default encoding' do
      expect(described_class).to be_valid(described_class::REPLACING)
    end

    it 'accepts UCS-2' do
      expect(described_class).to be_valid(2)
    end

    it 'accepts an encoding written as a string' do
      expect(described_class).to be_valid('1')
    end

    it 'rejects an encoding ODT does not define' do
      expect(described_class).not_to be_valid(3)
    end

    it 'rejects a word' do
      expect(described_class).not_to be_valid('ucs2')
    end

    it 'rejects nil' do
      expect(described_class).not_to be_valid(nil)
    end
  end
end

# frozen_string_literal: true

require 'odt_sdk'

RSpec.describe OdtSdk::Bulk::Batch do
  let(:numbers) { %w[5500000010 5500000011] }

  describe '#items' do
    it 'builds one item per number' do
      batch = described_class.new numbers: numbers, message: 'Tu codigo es 123456', carrier: 1

      expect(batch.items.size).to eq(2)
    end

    it 'merges the shared fields into every item' do
      batch = described_class.new numbers: numbers, message: 'Tu codigo es 123456', carrier: 1

      expect(batch.items.first).to eq(message: 'Tu codigo es 123456', carrier: 1, number: '5500000010')
    end

    it 'keeps recipient hashes as given' do
      batch = described_class.new recipients: [{ number: '5500000010', message: 'uno', carrier: 1 }]

      expect(batch.items).to eq([{ number: '5500000010', message: 'uno', carrier: 1 }])
    end

    it 'normalizes string keys on recipients' do
      batch = described_class.new recipients: [{ 'number' => '5500000010', 'message' => 'uno' }]

      expect(batch.items.first).to eq(number: '5500000010', message: 'uno')
    end

    it 'lets a recipient override a shared field' do
      batch = described_class.new recipients: [{ number: '5500000010', message: 'propio' }],
                                  message: 'compartido', carrier: 1

      expect(batch.items.first).to eq(number: '5500000010', message: 'propio', carrier: 1)
    end

    it 'drops repeated numbers' do
      batch = described_class.new numbers: %w[5500000010 5500000010 5500000011], message: 'uno'

      expect(batch.items.size).to eq(2)
    end

    it 'compares repeated numbers as strings' do
      batch = described_class.new recipients: [{ number: '5500000010' }, { number: 5_500_000_010 }]

      expect(batch.items.size).to eq(1)
    end

    it 'builds the items only once' do
      batch = described_class.new numbers: numbers, message: 'uno'

      expect(batch.items).to be(batch.items)
    end
  end

  describe '#each' do
    it 'yields every item' do
      batch = described_class.new numbers: numbers, message: 'uno'

      expect(batch.map { |item| item[:number] }).to eq(numbers)
    end
  end

  describe '#size' do
    it 'counts the items' do
      expect(described_class.new(numbers: numbers, message: 'uno').size).to eq(2)
    end
  end

  describe 'validation' do
    it 'rejects a batch without a source' do
      expect { described_class.new message: 'uno' }
        .to raise_error(ArgumentError, described_class::SOURCE_REQUIRED)
    end

    it 'rejects a batch carrying both sources' do
      expect { described_class.new numbers: numbers, recipients: [{ number: '5500000010' }] }
        .to raise_error(ArgumentError, described_class::SOURCE_REQUIRED)
    end

    it 'rejects a source that is not an array' do
      expect { described_class.new numbers: '5500000010' }
        .to raise_error(ArgumentError, described_class::SOURCE_REQUIRED)
    end

    it 'rejects an empty source' do
      expect { described_class.new numbers: [] }
        .to raise_error(ArgumentError, /at least one recipient/)
    end

    it 'rejects a recipient that is not a hash' do
      batch = described_class.new recipients: ['5500000010']

      expect { batch.items }.to raise_error(ArgumentError, /must be a Hash/)
    end
  end
end

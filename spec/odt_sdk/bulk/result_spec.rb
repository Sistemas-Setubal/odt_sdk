# frozen_string_literal: true

require 'odt_sdk'

RSpec.describe OdtSdk::Bulk::Result do
  subject(:result) { described_class.new [sent, temporary, invalid, enqueued] }

  let :sent do
    OdtSdk::Bulk::Delivery.from_response({ number: '5500000010' },
                                         OdtSdk::Response.new(status: 200, body: FakeTransport::SUCCESS))
  end

  let :temporary do
    OdtSdk::Bulk::Delivery.from_response({ number: '5500000011' },
                                         OdtSdk::Response.new(status: 200,
                                                              body: FakeTransport::TEMPORARY_FAILURE))
  end

  let(:invalid) { OdtSdk::Bulk::Delivery.from_error({ number: 'bad' }, ArgumentError.new('bad number')) }
  let(:enqueued) { OdtSdk::Bulk::Delivery.enqueued number: '5500000013' }

  describe '#size' do
    it 'counts every delivery' do
      expect(result.size).to eq(4)
    end
  end

  describe '#successes' do
    it 'keeps the delivered ones' do
      expect(result.successes).to eq([sent])
    end
  end

  describe '#failures' do
    it 'keeps the failed ones' do
      expect(result.failures).to eq([temporary, invalid])
    end
  end

  describe '#retryable' do
    it 'keeps the ones worth sending again' do
      expect(result.retryable).to eq([temporary])
    end
  end

  describe '#enqueued' do
    it 'keeps the handed off ones' do
      expect(result.enqueued).to eq([enqueued])
    end
  end

  describe '#success?' do
    it 'is false while a delivery failed' do
      expect(result).not_to be_success
    end

    it 'is true once every delivery landed' do
      expect(described_class.new([sent])).to be_success
    end

    it 'is true for a fully enqueued batch' do
      expect(described_class.new([enqueued])).to be_success
    end
  end

  describe '#failure?' do
    it 'is the opposite of success' do
      expect(result).to be_failure
    end
  end

  describe '#numbers' do
    it 'lists the numbers as strings' do
      expect(result.numbers).to eq(%w[5500000010 5500000011 bad 5500000013])
    end
  end

  describe '#each' do
    it 'yields every delivery' do
      expect(result.map(&:status)).to eq(%i[success temporary_failure invalid enqueued])
    end
  end

  describe '#to_h' do
    it 'summarizes the batch' do
      expect(result.to_h).to include(total: 4, successes: 1, failures: 2)
    end

    it 'summarizes every delivery' do
      expect(result.to_h[:deliveries].first).to eq(sent.to_h)
    end
  end
end

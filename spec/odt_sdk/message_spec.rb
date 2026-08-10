# frozen_string_literal: true

require 'odt_sdk'

RSpec.describe OdtSdk::Message do
  subject :sms do
    described_class.new service_id: 'EXAMPLE_1', number: '5500000010', carrier: 1, message: 'Tu codigo es 123456'
  end

  describe 'accessors' do
    it 'reads the service_id' do
      expect(sms.service_id).to eq('EXAMPLE_1')
    end

    it 'reads the number' do
      expect(sms.number).to eq('5500000010')
    end

    it 'reads the carrier' do
      expect(sms.carrier).to eq(1)
    end

    it 'reads the message' do
      expect(sms.message).to eq('Tu codigo es 123456')
    end
  end

  describe '#to_notify' do
    it 'carries the service_id' do
      expect(sms.to_notify[:service_id]).to eq('EXAMPLE_1')
    end

    it 'carries the number' do
      expect(sms.to_notify[:number]).to eq('5500000010')
    end

    it 'carries the carrier as a string' do
      expect(sms.to_notify[:carrier]).to eq('1')
    end

    it 'carries the message' do
      expect(sms.to_notify[:message]).to eq('Tu codigo es 123456')
    end

    it 'exposes only the four ODT fields' do
      expect(sms.to_notify.keys).to contain_exactly(:service_id, :number, :carrier, :message)
    end

    it 'stringifies a numeric number' do
      notify = described_class.new(service_id: 'EXAMPLE_1', number: 5_500_000_010, carrier: 0, message: 'hi').to_notify

      expect(notify[:number]).to eq('5500000010')
    end

    it 'stringifies a symbol service_id' do
      notify = described_class.new(service_id: :EXAMPLE_1, number: '5500000010', carrier: 0, message: 'hi').to_notify

      expect(notify[:service_id]).to eq('EXAMPLE_1')
    end

    it 'is serializable as the JSON ODT documents' do
      expect(JSON.parse(JSON.generate(sms.to_notify))).to eq(
        'service_id' => 'EXAMPLE_1', 'number' => '5500000010', 'carrier' => '1', 'message' => 'Tu codigo es 123456'
      )
    end
  end
end

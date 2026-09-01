# frozen_string_literal: true

require 'odt_sdk'

RSpec.describe OdtSdk::Bulk::Delivery do
  let(:item) { { number: '5500000010', message: 'Tu codigo es 123456', carrier: 1 } }

  def response(body)
    OdtSdk::Response.new status: 200, body: body
  end

  describe '.from_response' do
    it 'takes the status from the response' do
      delivery = described_class.from_response item, response(FakeTransport::SUCCESS)

      expect(delivery.status).to eq(:success)
    end

    it 'keeps the response' do
      reply = response FakeTransport::QUEUED
      delivery = described_class.from_response item, reply

      expect(delivery.response).to be(reply)
    end

    it 'marks a temporary failure as retryable' do
      delivery = described_class.from_response item, response(FakeTransport::TEMPORARY_FAILURE)

      expect(delivery).to be_retryable
    end

    it 'marks a malformed answer as a failure' do
      delivery = described_class.from_response item, response(FakeTransport::MALFORMED)

      expect(delivery).to be_failure
    end
  end

  describe '.from_error' do
    it 'maps a validation error to invalid' do
      delivery = described_class.from_error item, ArgumentError.new('bad number')

      expect(delivery.status).to eq(:invalid)
    end

    it 'maps a transport error to transport_error' do
      delivery = described_class.from_error item, OdtSdk::TransportError.new('down')

      expect(delivery.status).to eq(:transport_error)
    end

    it 'marks a transport error as retryable' do
      delivery = described_class.from_error item, OdtSdk::TransportError.new('down')

      expect(delivery).to be_retryable
    end

    it 'maps anything else to error' do
      delivery = described_class.from_error item, RuntimeError.new('boom')

      expect(delivery.status).to eq(:error)
    end

    it 'keeps the error' do
      error = ArgumentError.new 'bad number'

      expect(described_class.from_error(item, error).error).to be(error)
    end
  end

  describe '.enqueued' do
    it 'builds an enqueued delivery' do
      expect(described_class.enqueued(item)).to be_enqueued
    end

    it 'does not count as a success' do
      expect(described_class.enqueued(item)).not_to be_success
    end

    it 'does not count as a failure' do
      expect(described_class.enqueued(item)).not_to be_failure
    end
  end

  describe '#reason' do
    it 'reads the error message first' do
      delivery = described_class.from_error item, ArgumentError.new('bad number')

      expect(delivery.reason).to eq('bad number')
    end

    it 'falls back to the api message' do
      delivery = described_class.from_response item, response(FakeTransport::SUCCESS)

      expect(delivery.reason).to eq('success sms sent')
    end

    it 'is nil without a response or an error' do
      expect(described_class.enqueued(item).reason).to be_nil
    end
  end

  describe '#item' do
    it 'keeps the fields the delivery was built from' do
      delivery = described_class.from_error item, ArgumentError.new('bad number')

      expect(delivery.item).to be(item)
    end

    it 'reads the number off the item' do
      expect(described_class.enqueued(item).number).to eq('5500000010')
    end
  end

  describe '#to_h' do
    it 'summarizes the delivery' do
      delivery = described_class.from_error item, ArgumentError.new('bad number')

      expect(delivery.to_h).to eq(number: '5500000010', status: :invalid, reason: 'bad number')
    end

    it 'drops a missing reason' do
      expect(described_class.enqueued(item).to_h).to eq(number: '5500000010', status: :enqueued)
    end
  end

  describe 'validation' do
    it 'rejects an unknown status' do
      expect { described_class.new item: item, status: :sent }
        .to raise_error(ArgumentError, /Unknown delivery status :sent/)
    end
  end
end

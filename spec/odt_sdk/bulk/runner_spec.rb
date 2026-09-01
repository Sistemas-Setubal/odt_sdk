# frozen_string_literal: true

require 'odt_sdk'

RSpec.describe OdtSdk::Bulk::Runner do
  subject(:runner) { described_class.new client }

  let :configuration do
    OdtSdk::Configuration.new.tap do |config|
      config.partner_id = 'ODT_OTP'
      config.secure_key = 'EXAMPLE'
      config.service_id = 'EXAMPLE_1'
    end
  end

  let(:transport) { FakeTransport.new }
  let(:client) { OdtSdk::Client.new configuration, transport: transport }

  def batch(*numbers)
    OdtSdk::Bulk::Batch.new numbers: numbers, message: 'Tu codigo es 123456', carrier: 1
  end

  describe '#pool' do
    it 'defaults to a sequential pool' do
      expect(runner.pool.workers).to eq(1)
    end

    it 'keeps the injected pool' do
      pool = OdtSdk::Bulk::Pool.new concurrency: 3

      expect(described_class.new(client, pool: pool).pool).to be(pool)
    end
  end

  describe '#call' do
    it 'sends one request per number' do
      runner.call batch('5500000010', '5500000011')

      expect(transport.numbers).to eq(%w[5500000010 5500000011])
    end

    it 'answers a delivery per number' do
      expect(runner.call(batch('5500000010', '5500000011')).size).to eq(2)
    end

    it 'reports the successful ones' do
      expect(runner.call(batch('5500000010')).successes.size).to eq(1)
    end

    it 'skips the request for an invalid number' do
      runner.call batch('bad', '5500000011')

      expect(transport.numbers).to eq(%w[5500000011])
    end

    it 'keeps going after an invalid number' do
      expect(runner.call(batch('bad', '5500000011')).successes.size).to eq(1)
    end

    it 'reports an invalid number as a failure' do
      expect(runner.call(batch('bad')).failures.first.status).to eq(:invalid)
    end

    it 'keeps going after a transport error' do
      transport = FakeTransport.new errors: { '5500000010' => OdtSdk::TransportError.new('down') }
      runner = described_class.new OdtSdk::Client.new(configuration, transport: transport)

      result = runner.call batch('5500000010', '5500000011')

      expect(result.retryable.size).to eq(1)
    end

    it 'reports the api failures' do
      transport = FakeTransport.new bodies: { '5500000010' => FakeTransport::TEMPORARY_FAILURE }
      runner = described_class.new OdtSdk::Client.new(configuration, transport: transport)

      expect(runner.call(batch('5500000010')).failures.first.status).to eq(:temporary_failure)
    end

    it 'sends through the injected pool' do
      pool = OdtSdk::Bulk::Pool.new concurrency: 3
      result = described_class.new(client, pool: pool).call batch('5500000010', '5500000011')

      expect(result.numbers).to eq(%w[5500000010 5500000011])
    end
  end

  describe 'with a dispatcher' do
    let(:queued) { [] }
    let(:runner) { described_class.new client, dispatcher: ->(item) { queued << item } }

    it 'hands every item to the dispatcher' do
      runner.call batch('5500000010', '5500000011')

      expect(queued.map { |item| item[:number] }).to eq(%w[5500000010 5500000011])
    end

    it 'sends nothing itself' do
      runner.call batch('5500000010')

      expect(transport.requests).to be_empty
    end

    it 'reports the items as enqueued' do
      expect(runner.call(batch('5500000010')).enqueued.size).to eq(1)
    end

    it 'hands over items the host app can serialize' do
      runner.call batch('5500000010')

      expect(queued.first).to eq(number: '5500000010', message: 'Tu codigo es 123456', carrier: 1)
    end

    it 'keeps going when the dispatcher blows up' do
      runner = described_class.new client, dispatcher: ->(_item) { raise 'redis is down' }

      expect(runner.call(batch('5500000010')).failures.first.status).to eq(:error)
    end
  end
end

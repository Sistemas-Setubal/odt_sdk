# frozen_string_literal: true

require 'odt_sdk'

RSpec.describe OdtSdk::Otp::MemoryStore do
  subject(:store) { described_class.new }

  it_behaves_like 'an OTP store'

  describe 'what it keeps in memory' do
    it 'holds the code as it was given, which is why this store is single process' do
      store.write '5500000010', '0473'

      expect(store.read('5500000010').code).to eq('0473')
    end
  end

  describe 'housekeeping' do
    let(:now) { Time.now }

    def freeze_clock(at)
      allow(Time).to receive(:now).and_return(at)
    end

    it 'drops entries long past their expiry when something new is written' do
      freeze_clock now
      store.write '5500000010', '0473', ttl: 300
      freeze_clock now + described_class::PURGE_AFTER + 400
      store.write '5500000011', '1234'

      expect(store.read('5500000010')).to be_nil
    end

    it 'keeps recently expired entries so they still report as expired' do
      freeze_clock now
      store.write '5500000010', '0473', ttl: 300
      freeze_clock now + 400
      store.write '5500000011', '1234'

      expect(store.read('5500000010')).to be_expired
    end
  end

  describe 'the send window' do
    let(:now) { Time.now }

    def freeze_clock(at)
      allow(Time).to receive(:now).and_return(at)
    end

    it 'starts over once the window has passed' do
      freeze_clock now
      3.times { store.record_send '5500000010', window: 900 }
      freeze_clock now + 901

      expect(store.record_send('5500000010', window: 900)).to eq(1)
    end

    it 'keeps counting just before the window rolls over' do
      freeze_clock now
      3.times { store.record_send '5500000010', window: 900 }
      freeze_clock now + 899

      expect(store.record_send('5500000010', window: 900)).to eq(4)
    end
  end

  describe 'concurrency' do
    it 'counts every attempt when threads race' do
      store.write '5500000010', '0473'
      Array.new(8) { Thread.new { 50.times { store.increment_attempts '5500000010' } } }.each(&:join)

      expect(store.read('5500000010').attempts).to eq(400)
    end

    it 'loses no send when threads race' do
      Array.new(8) { Thread.new { 50.times { store.record_send '5500000010', window: 900 } } }.each(&:join)

      expect(store.record_send('5500000010', window: 900)).to eq(401)
    end
  end
end

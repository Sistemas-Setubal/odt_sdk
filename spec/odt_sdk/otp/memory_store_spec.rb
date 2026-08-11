# frozen_string_literal: true

require 'odt_sdk'

RSpec.describe OdtSdk::Otp::MemoryStore do
  subject(:store) { described_class.new }

  let(:number) { '5500000010' }
  let(:now) { Time.now }

  def freeze_clock(at = now)
    allow(Time).to receive(:now).and_return(at)
  end

  describe '#write' do
    it 'stores the code against the number' do
      store.write number, '0473'

      expect(store.read(number).code).to eq('0473')
    end

    it 'starts with no attempts spent' do
      store.write number, '0473'

      expect(store.read(number).attempts).to eq(0)
    end

    it 'expires five minutes out by default' do
      freeze_clock
      store.write number, '0473'

      expect(store.read(number).expires_at).to eq(now + 300)
    end

    it 'names that default in a constant' do
      expect(described_class::DEFAULT_TTL).to eq(300)
    end

    it 'honours a custom ttl' do
      freeze_clock
      store.write number, '0473', ttl: 60

      expect(store.read(number).expires_at).to eq(now + 60)
    end

    it 'accepts a numeric number as the key' do
      store.write 5_500_000_010, '0473'

      expect(store.read('5500000010').code).to eq('0473')
    end

    it 'replaces a code already stored for that number' do
      store.write number, '0473'
      store.write number, '1234'

      expect(store.read(number).code).to eq('1234')
    end

    it 'resets the attempts when a new code is written' do
      store.write number, '0473'
      store.increment_attempts number
      store.write number, '1234'

      expect(store.read(number).attempts).to eq(0)
    end

    it 'keeps codes for different numbers apart' do
      store.write number, '0473'
      store.write '5500000011', '1234'

      expect(store.read(number).code).to eq('0473')
    end

    it 'rejects a ttl of zero' do
      expect { store.write number, '0473', ttl: 0 }.to raise_error(ArgumentError, /positive/)
    end

    it 'rejects a negative ttl' do
      expect { store.write number, '0473', ttl: -60 }.to raise_error(ArgumentError, /positive/)
    end

    it 'rejects a ttl that is not a number' do
      expect { store.write number, '0473', ttl: '60' }.to raise_error(ArgumentError, /"60"/)
    end
  end

  describe '#read' do
    it 'is nil for a number never written' do
      expect(store.read(number)).to be_nil
    end

    it 'is not expired inside the ttl' do
      freeze_clock
      store.write number, '0473', ttl: 300
      freeze_clock now + 299

      expect(store.read(number)).not_to be_expired
    end

    it 'is expired once the ttl has passed' do
      freeze_clock
      store.write number, '0473', ttl: 300
      freeze_clock now + 301

      expect(store.read(number)).to be_expired
    end

    it 'is expired exactly at the ttl boundary' do
      freeze_clock
      store.write number, '0473', ttl: 300
      freeze_clock now + 300

      expect(store.read(number)).to be_expired
    end

    it 'still returns an expired entry, so expiry can be told from never sent' do
      freeze_clock
      store.write number, '0473', ttl: 300
      freeze_clock now + 301

      expect(store.read(number).code).to eq('0473')
    end
  end

  describe '#increment_attempts' do
    it 'counts an attempt' do
      store.write number, '0473'
      store.increment_attempts number

      expect(store.read(number).attempts).to eq(1)
    end

    it 'counts each attempt' do
      store.write number, '0473'
      3.times { store.increment_attempts number }

      expect(store.read(number).attempts).to eq(3)
    end

    it 'leaves the code alone' do
      store.write number, '0473'
      store.increment_attempts number

      expect(store.read(number).code).to eq('0473')
    end

    it 'leaves the expiry alone' do
      freeze_clock
      store.write number, '0473', ttl: 300
      store.increment_attempts number

      expect(store.read(number).expires_at).to eq(now + 300)
    end

    it 'does nothing for a number never written' do
      expect { store.increment_attempts number }.not_to raise_error
    end

    it 'leaves an unknown number unstored' do
      store.increment_attempts number

      expect(store.read(number)).to be_nil
    end
  end

  describe '#delete' do
    it 'forgets the code' do
      store.write number, '0473'
      store.delete number

      expect(store.read(number)).to be_nil
    end

    it 'is quiet about a number never written' do
      expect { store.delete number }.not_to raise_error
    end

    it 'leaves other numbers alone' do
      store.write number, '0473'
      store.write '5500000011', '1234'
      store.delete number

      expect(store.read('5500000011').code).to eq('1234')
    end
  end

  describe 'housekeeping' do
    it 'drops entries long past their expiry when something new is written' do
      freeze_clock
      store.write number, '0473', ttl: 300
      freeze_clock now + described_class::PURGE_AFTER + 400
      store.write '5500000011', '1234'

      expect(store.read(number)).to be_nil
    end

    it 'keeps recently expired entries so they still report as expired' do
      freeze_clock
      store.write number, '0473', ttl: 300
      freeze_clock now + 400
      store.write '5500000011', '1234'

      expect(store.read(number)).to be_expired
    end
  end

  describe 'concurrency' do
    it 'counts every attempt when threads race' do
      store.write number, '0473'
      Array.new(8) { Thread.new { 50.times { store.increment_attempts number } } }.each(&:join)

      expect(store.read(number).attempts).to eq(400)
    end
  end
end

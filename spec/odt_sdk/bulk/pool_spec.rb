# frozen_string_literal: true

require 'timeout'

require 'odt_sdk'

RSpec.describe OdtSdk::Bulk::Pool do
  describe '.normalize_concurrency' do
    it 'defaults to one worker' do
      expect(described_class.normalize_concurrency(nil)).to eq(1)
    end

    it 'reads a numeric string' do
      expect(described_class.normalize_concurrency('4')).to eq(4)
    end

    it 'rejects zero' do
      expect { described_class.normalize_concurrency 0 }
        .to raise_error(ArgumentError, /Invalid concurrency 0/)
    end

    it 'rejects a value that is not a number' do
      expect { described_class.normalize_concurrency 'many' }
        .to raise_error(ArgumentError, /Invalid concurrency "many"/)
    end
  end

  describe '.normalize_throttle' do
    it 'stays nil without a throttle' do
      expect(described_class.normalize_throttle(nil)).to be_nil
    end

    it 'reads a numeric string' do
      expect(described_class.normalize_throttle('0.25')).to eq(0.25)
    end

    it 'rejects a negative pause' do
      expect { described_class.normalize_throttle(-1) }
        .to raise_error(ArgumentError, /Invalid throttle -1/)
    end

    it 'rejects a value that is not a number' do
      expect { described_class.normalize_throttle 'slow' }
        .to raise_error(ArgumentError, /Invalid throttle "slow"/)
    end
  end

  describe '#map' do
    it 'maps every item in order' do
      expect(described_class.new.map([1, 2, 3]) { |item| item * 2 }).to eq([2, 4, 6])
    end

    it 'keeps the input order across workers' do
      pool = described_class.new concurrency: 4

      expect(pool.map([1, 2, 3, 4, 5, 6]) { |item| item * 2 }).to eq([2, 4, 6, 8, 10, 12])
    end

    it 'runs the items on several threads' do
      pool = described_class.new concurrency: 2
      gate = Queue.new

      outcome = Timeout.timeout 5 do
        pool.map [1, 2] do |item|
          gate << item
          sleep 0.01 while gate.size < 2
          item
        end
      end

      expect(outcome).to eq([1, 2])
    end

    it 'handles an empty list' do
      expect(described_class.new(concurrency: 2).map([]) { |item| item }).to eq([])
    end

    it 'pauses between sequential sends' do
      pool = described_class.new throttle: 0.01
      allow(pool).to receive(:sleep)

      pool.map([1, 2]) { |item| item }

      expect(pool).to have_received(:sleep).with(0.01).twice
    end

    it 'pauses inside every worker' do
      pool = described_class.new concurrency: 2, throttle: 0.01
      allow(pool).to receive(:sleep)

      pool.map([1, 2]) { |item| item }

      expect(pool).to have_received(:sleep).with(0.01).twice
    end
  end
end

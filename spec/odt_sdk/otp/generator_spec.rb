# frozen_string_literal: true

require 'odt_sdk'

RSpec.describe OdtSdk::Otp::Generator do
  describe '.numeric' do
    it 'defaults to four digits' do
      expect(described_class.numeric.length).to eq(4)
    end

    it 'names that default in a constant' do
      expect(described_class::DEFAULT_LENGTH).to eq(4)
    end

    it 'honours a requested length' do
      expect(described_class.numeric(6).length).to eq(6)
    end

    it 'honours a long requested length' do
      expect(described_class.numeric(10).length).to eq(10)
    end

    it 'returns a string' do
      expect(described_class.numeric).to be_a(String)
    end

    it 'returns digits only' do
      expect(described_class.numeric(8)).to match(/\A\d{8}\z/)
    end

    it 'keeps the length when the draw has leading zeros' do
      allow(SecureRandom).to receive(:random_number).and_return(7)

      expect(described_class.numeric(6)).to eq('000007')
    end

    it 'keeps the length when the draw is zero' do
      allow(SecureRandom).to receive(:random_number).and_return(0)

      expect(described_class.numeric).to eq('0000')
    end

    it 'draws from the whole range for the requested length' do
      allow(SecureRandom).to receive(:random_number).and_return(0)
      described_class.numeric 6

      expect(SecureRandom).to have_received(:random_number).with(1_000_000)
    end

    it 'never exceeds the requested length' do
      expect(Array.new(200) { described_class.numeric(4).length }).to all(eq(4))
    end

    it 'is drawn with SecureRandom rather than Kernel#rand' do
      allow(SecureRandom).to receive(:random_number).and_return(1234)

      expect(described_class.numeric).to eq('1234')
    end

    it 'does not repeat itself over many draws' do
      expect(Array.new(500) { described_class.numeric(8) }.uniq.size).to be > 400
    end

    it 'rejects a length of zero' do
      expect { described_class.numeric(0) }.to raise_error(ArgumentError, /positive integer/)
    end

    it 'rejects a negative length' do
      expect { described_class.numeric(-1) }.to raise_error(ArgumentError, /positive integer/)
    end

    it 'rejects a length that is not an integer' do
      expect { described_class.numeric(4.5) }.to raise_error(ArgumentError, /4.5/)
    end

    it 'rejects a length written as a string' do
      expect { described_class.numeric('6') }.to raise_error(ArgumentError, /"6"/)
    end

    it 'rejects a nil length' do
      expect { described_class.numeric(nil) }.to raise_error(ArgumentError, /nil/)
    end

    it 'keeps the length check private' do
      expect(described_class).not_to respond_to(:validate_length)
    end
  end
end

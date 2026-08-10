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

    it 'omits encode when it was not given' do
      expect(sms.to_notify).not_to have_key(:encode)
    end

    it 'is serializable as the JSON ODT documents' do
      expect(JSON.parse(JSON.generate(sms.to_notify))).to eq(
        'service_id' => 'EXAMPLE_1', 'number' => '5500000010', 'carrier' => '1', 'message' => 'Tu codigo es 123456'
      )
    end
  end

  describe 'encode' do
    def notify_with(encode)
      described_class.new(service_id: 'EXAMPLE_1', number: '5500000010', carrier: 1,
                          message: 'hi', encode: encode).to_notify
    end

    it 'carries UCS-2 as a string' do
      expect(notify_with(OdtSdk::Encodings::UCS2)[:encode]).to eq('2')
    end

    it 'carries the replacing encoding, explicit zero and all' do
      expect(notify_with(OdtSdk::Encodings::REPLACING)[:encode]).to eq('0')
    end

    it 'reads it back off the message' do
      expect(described_class.new(service_id: 'A', number: '1', carrier: 0, message: 'hi', encode: 2).encode).to eq(2)
    end
  end

  describe 'validation' do
    def build(**overrides)
      described_class.new(**{ service_id: 'EXAMPLE_1', number: '5500000010',
                              carrier: 1, message: 'Tu codigo es 123456' }.merge(overrides))
    end

    it 'passes a well formed message' do
      expect(build.validate).to be(true)
    end

    it 'returns itself so it chains' do
      expect(build.validate!).to be_a(described_class)
    end

    it 'reports a bad message without raising' do
      expect(build(number: '55').validate).to be(false)
    end

    it 'accepts an MSISDN of ten digits' do
      expect(build(number: '5500000010').validate).to be(true)
    end

    it 'rejects a number with nine digits' do
      expect { build(number: '550000001').validate! }.to raise_error(ArgumentError, /10 digits/)
    end

    it 'rejects a number with eleven digits' do
      expect { build(number: '55000000101').validate! }.to raise_error(ArgumentError, /10 digits/)
    end

    it 'rejects a number with a country prefix' do
      expect { build(number: '+525500000010').validate! }.to raise_error(ArgumentError, /10 digits/)
    end

    it 'rejects a formatted number' do
      expect { build(number: '55 0000 0010').validate! }.to raise_error(ArgumentError, /10 digits/)
    end

    it 'rejects a nil number' do
      expect { build(number: nil).validate! }.to raise_error(ArgumentError, /number/)
    end

    it 'accepts every carrier ODT documents' do
      expect(OdtSdk::Carriers::ALL.map { |carrier| build(carrier: carrier).validate }).to all(be(true))
    end

    it 'rejects a carrier ODT does not define' do
      expect { build(carrier: 99).validate! }.to raise_error(ArgumentError, /Invalid carrier/)
    end

    it 'names the valid carriers in the error' do
      expect { build(carrier: 99).validate! }.to raise_error(ArgumentError, /0, 1, 2, 3/)
    end

    it 'rejects a nil carrier' do
      expect { build(carrier: nil).validate! }.to raise_error(ArgumentError, /Invalid carrier/)
    end

    it 'rejects a missing service_id' do
      expect { build(service_id: nil).validate! }.to raise_error(ArgumentError, /service_id/)
    end

    it 'rejects a blank service_id' do
      expect { build(service_id: '  ').validate! }.to raise_error(ArgumentError, /service_id/)
    end

    it 'rejects an empty message' do
      expect { build(message: '').validate! }.to raise_error(ArgumentError, /message/)
    end

    it 'rejects a whitespace only message' do
      expect { build(message: "  \n ").validate! }.to raise_error(ArgumentError, /message/)
    end

    it 'accepts every encoding ODT documents' do
      expect(OdtSdk::Encodings::ALL.map { |encode| build(encode: encode).validate }).to all(be(true))
    end

    it 'accepts a message without an encoding' do
      expect(build(encode: nil).validate).to be(true)
    end

    it 'rejects an encoding ODT does not define' do
      expect { build(encode: 9).validate! }.to raise_error(ArgumentError, /Invalid encode/)
    end

    it 'names the valid encodings in the error' do
      expect { build(encode: 9).validate! }.to raise_error(ArgumentError, /0, 1, 2/)
    end

    it 'rejects an accent under the default encoding' do
      expect { build(message: 'Tu código es 123456').validate! }
        .to raise_error(ArgumentError, /without accents/)
    end

    it 'points at UCS-2 as the way out' do
      expect { build(message: 'Tu código es 123456').validate! }
        .to raise_error(ArgumentError, /UCS2/)
    end

    it 'rejects an accent under strict GSM' do
      expect(build(message: 'Tu código', encode: OdtSdk::Encodings::GSM).validate).to be(false)
    end

    it 'accepts an accent under UCS-2' do
      expect(build(message: 'Tu código', encode: OdtSdk::Encodings::UCS2).validate).to be(true)
    end

    it 'accepts OTP copy written without accents' do
      expect(build(message: 'Tu codigo de verificacion es 123456').validate).to be(true)
    end

    it 'validates before serializing' do
      expect { build(carrier: 99).to_notify }.to raise_error(ArgumentError, /Invalid carrier/)
    end
  end

  describe 'unknown and missing fields' do
    it 'rejects a field ODT does not define' do
      expect { described_class.new service_id: 'A', number: '1', carrier: 0, message: 'hi', sender: 'ODT' }
        .to raise_error(ArgumentError, /sender/)
    end

    it 'demands the required fields' do
      expect { described_class.new number: '1', carrier: 0 }
        .to raise_error(ArgumentError, /service_id, message/)
    end
  end
end

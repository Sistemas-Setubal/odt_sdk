# frozen_string_literal: true

require 'odt_sdk'

RSpec.describe OdtSdk::Client do
  subject(:client) { described_class.new configuration, transport: transport }

  let :configuration do
    OdtSdk::Configuration.new.tap do |config|
      config.partner_id = 'ODT_OTP'
      config.secure_key = 'EXAMPLE'
    end
  end

  let(:transport) { FakeTransport.new }

  let(:notify) { { notify: { number: '5500000010', message: 'Tu codigo es 123456' } } }
  let(:sent) { transport.requests.last[:payload] }

  describe '#send_url' do
    it 'appends the send path to the configured base url' do
      expect(client.send_url).to eq('https://smsapi.odt.com.mx/sendsms')
    end

    it 'tolerates a trailing slash on the base url' do
      configuration.base_url = 'https://staging.example.com/'

      expect(client.send_url).to eq('https://staging.example.com/sendsms')
    end
  end

  describe '#transport' do
    it 'keeps the injected transport' do
      expect(client.transport).to be(transport)
    end

    it 'defaults to the HTTParty transport' do
      expect(described_class.new(configuration).transport).to be_a(OdtSdk::Transport::HttpParty)
    end

    it 'hands the configured timeout to the default transport' do
      configuration.timeout = 45

      expect(described_class.new(configuration).transport.timeout).to eq(45)
    end

    it 'builds the default transport only once' do
      client = described_class.new configuration

      expect(client.transport).to be(client.transport)
    end
  end

  describe '#send_sms' do
    before { configuration.service_id = 'EXAMPLE_1' }

    def send_it(**overrides)
      client.send_sms(**{ number: '5500000010', message: 'Tu codigo es 123456', carrier: 1 }.merge(overrides))
    end

    it 'posts to the send url' do
      send_it

      expect(transport.requests.last[:url]).to eq('https://smsapi.odt.com.mx/sendsms')
    end

    it 'builds the notify block' do
      send_it

      expect(sent[:notify]).to eq(service_id: 'EXAMPLE_1', number: '5500000010',
                                  carrier: '1', message: 'Tu codigo es 123456')
    end

    it 'signs the request' do
      send_it

      expect(sent[:security][:partner_id]).to eq('ODT_OTP')
    end

    it 'falls back to the configured service_id' do
      send_it

      expect(sent[:notify][:service_id]).to eq('EXAMPLE_1')
    end

    it 'prefers an explicit service_id over the configured one' do
      send_it service_id: 'EXAMPLE_2'

      expect(sent[:notify][:service_id]).to eq('EXAMPLE_2')
    end

    it 'stringifies a numeric carrier' do
      send_it carrier: 3

      expect(sent[:notify][:carrier]).to eq('3')
    end

    it 'returns a Response' do
      expect(send_it).to be_a(OdtSdk::Response)
    end

    it 'parses the ODT code' do
      expect(send_it.code).to eq('0')
    end

    it 'demands a number' do
      expect { client.send_sms message: 'Tu codigo es 123456', carrier: 1 }
        .to raise_error(ArgumentError, /number/)
    end

    it 'demands a message' do
      expect { client.send_sms number: '5500000010', carrier: 1 }
        .to raise_error(ArgumentError, /message/)
    end

    it 'demands a carrier' do
      expect { client.send_sms number: '5500000010', message: 'Tu codigo es 123456' }
        .to raise_error(ArgumentError, /carrier/)
    end

    it 'rejects a field ODT does not know' do
      expect { send_it sender: 'ODT' }.to raise_error(ArgumentError, /sender/)
    end

    it 'never reaches the transport with a bad field' do
      expect { attempt_bad_send }.not_to change(transport.requests, :size)
    end

    it 'passes the encoding through' do
      send_it encode: OdtSdk::Encodings::UCS2

      expect(sent[:notify][:encode]).to eq('2')
    end

    it 'omits the optional fields when they are not given' do
      send_it

      expect(sent[:notify].keys).to contain_exactly(:service_id, :number, :carrier, :message)
    end

    it 'rejects a number that is not ten digits' do
      expect { send_it number: '55' }.to raise_error(ArgumentError, /10 digits/)
    end

    it 'rejects a carrier ODT does not define' do
      expect { send_it carrier: 99 }.to raise_error(ArgumentError, /Invalid carrier/)
    end

    it 'never reaches the transport with an invalid number' do
      expect { attempt_send number: '55' }.not_to change(transport.requests, :size)
    end

    it 'never reaches the transport with an invalid carrier' do
      expect { attempt_send carrier: 99 }.not_to change(transport.requests, :size)
    end

    def attempt_bad_send
      send_it sender: 'ODT'
    rescue ArgumentError
      nil
    end

    def attempt_send(**overrides)
      send_it(**overrides)
    rescue ArgumentError
      nil
    end
  end

  describe '#send_sms!' do
    subject(:client) { described_class.new configuration, transport: failing_transport }

    let :failing_transport do
      FakeTransport.new body: { 'result' => { 'code' => '101', 'message' => 'malformed' } }
    end

    def send_it!
      client.send_sms! number: '5500000010', message: 'Tu codigo es 123456',
                       carrier: 1, service_id: 'EXAMPLE_1'
    end

    it 'raises on a failing code' do
      expect { send_it! }.to raise_error(OdtSdk::ApiError)
    end

    it 'is a rescuable OdtSdk::Error' do
      expect { send_it! }.to raise_error(OdtSdk::Error)
    end

    it 'names the code in the message' do
      expect { send_it! }.to raise_error(OdtSdk::ApiError, /101/)
    end

    it 'carries the code' do
      expect { send_it! }.to raise_error(an_object_having_attributes(code: '101'))
    end

    it 'carries the api message' do
      expect { send_it! }.to raise_error(an_object_having_attributes(api_message: 'malformed'))
    end

    it 'carries the whole response' do
      expect { send_it! }.to raise_error(an_object_having_attributes(response: be_a(OdtSdk::Response)))
    end

    it 'still sent the request' do
      expect { send_it! }.to raise_error(OdtSdk::ApiError)
        .and(change { failing_transport.requests.size }.by(1))
    end
  end

  describe '#send_sms! on success' do
    before { configuration.service_id = 'EXAMPLE_1' }

    it 'returns the Response' do
      expect(client.send_sms!(number: '5500000010', message: 'hola', carrier: 1)).to be_a(OdtSdk::Response)
    end

    it 'does not raise' do
      expect { client.send_sms! number: '5500000010', message: 'hola', carrier: 1 }.not_to raise_error
    end
  end

  describe '#request!' do
    it 'returns the Response on success' do
      expect(client.request!(notify)).to be_a(OdtSdk::Response)
    end
  end

  describe '#request' do
    it 'posts to the send url' do
      client.request notify

      expect(transport.requests.last[:url]).to eq('https://smsapi.odt.com.mx/sendsms')
    end

    it 'injects a security block' do
      client.request notify

      expect(sent[:security].keys).to contain_exactly(:partner_id, :time, :hash)
    end

    it 'signs with the configured partner_id' do
      client.request notify

      expect(sent[:security][:partner_id]).to eq('ODT_OTP')
    end

    it 'hashes the very time it sends' do
      client.request notify

      expect(sent[:security][:hash]).to eq(
        OdtSdk::Security.hash_for(partner_id: 'ODT_OTP', time: sent[:security][:time], secure_key: 'EXAMPLE')
      )
    end

    it 'keeps the caller payload alongside the security block' do
      client.request notify

      expect(sent[:notify]).to eq(number: '5500000010', message: 'Tu codigo es 123456')
    end

    it 'overrides a caller-supplied security block' do
      client.request notify.merge(security: { partner_id: 'SPOOFED' })

      expect(sent[:security][:partner_id]).to eq('ODT_OTP')
    end

    it 'never lets the secure_key into the payload' do
      client.request notify

      expect(sent[:security].values).not_to include('EXAMPLE')
    end

    it 'builds a fresh security block on every request' do
      allow(OdtSdk::Security).to receive(:timestamp).and_return('1679590064554', '1679590064999')
      2.times { client.request notify }

      expect(transport.requests.map { |request| request[:payload][:security][:time] })
        .to eq(%w[1679590064554 1679590064999])
    end

    it 'returns a Response' do
      expect(client.request(notify)).to be_a(OdtSdk::Response)
    end

    it 'carries the http status into the Response' do
      expect(client.request(notify).http_status).to eq(200)
    end

    it 'parses the ODT code into the Response' do
      expect(client.request(notify).code).to eq('0')
    end

    it 'refuses to sign without credentials' do
      configuration.secure_key = nil

      expect { client.request notify }.to raise_error(OdtSdk::ConfigurationError)
    end

    it 'never reaches the transport without credentials' do
      configuration.partner_id = nil

      expect { attempt_request }.not_to change(transport.requests, :size)
    end
  end

  describe '#send_bulk' do
    before { configuration.service_id = 'EXAMPLE_1' }

    def send_many(**overrides)
      client.send_bulk(**{ numbers: %w[5500000010 5500000011],
                           message: 'Tu codigo es 123456', carrier: 1 }.merge(overrides))
    end

    it 'sends one request per number' do
      send_many

      expect(transport.numbers).to eq(%w[5500000010 5500000011])
    end

    it 'signs every request on its own' do
      send_many

      expect(transport.requests.map { |request| request[:payload][:security][:hash] }).to all(be_a(String))
    end

    it 'fills in the configured service_id' do
      send_many

      expect(transport.last_notify[:service_id]).to eq('EXAMPLE_1')
    end

    it 'answers a result carrying every delivery' do
      expect(send_many.size).to eq(2)
    end

    it 'reports the batch as successful' do
      expect(send_many).to be_success
    end

    it 'accepts a recipient hash per number' do
      result = client.send_bulk recipients: [{ number: '5500000010', message: 'uno', carrier: 1 },
                                             { number: '5500000011', message: 'dos', carrier: 1 }]

      expect(result.successes.size).to eq(2)
    end

    it 'sends the message each recipient carries' do
      client.send_bulk recipients: [{ number: '5500000010', message: 'uno', carrier: 1 }]

      expect(transport.last_notify[:message]).to eq('uno')
    end

    it 'sends each number only once' do
      send_many numbers: %w[5500000010 5500000010]

      expect(transport.requests.size).to eq(1)
    end

    it 'collects a bad number without dropping the rest' do
      expect(send_many(numbers: %w[bad 5500000011]).failures.size).to eq(1)
    end

    it 'spreads the batch across workers' do
      expect(send_many(concurrency: 2).successes.size).to eq(2)
    end

    it 'hands the batch to a dispatcher instead of sending it' do
      client.send_bulk numbers: %w[5500000010], message: 'uno', carrier: 1, dispatcher: ->(item) { item }

      expect(transport.requests).to be_empty
    end

    it 'rejects a batch without recipients' do
      expect { client.send_bulk message: 'uno' }.to raise_error(ArgumentError)
    end
  end

  describe '#send_bulk!' do
    before { configuration.service_id = 'EXAMPLE_1' }

    it 'answers the result when every message lands' do
      result = client.send_bulk! numbers: %w[5500000010], message: 'uno', carrier: 1

      expect(result).to be_success
    end

    it 'raises when a message fails' do
      expect { client.send_bulk! numbers: %w[bad], message: 'uno', carrier: 1 }
        .to raise_error(OdtSdk::BulkError, '1 of 1 bulk messages failed.')
    end

    it 'carries the result on the error' do
      client.send_bulk! numbers: %w[bad], message: 'uno', carrier: 1
    rescue OdtSdk::BulkError => error
      expect(error.result.failures.first.status).to eq(:invalid)
    end
  end

  def attempt_request
    client.request notify
  rescue OdtSdk::ConfigurationError
    nil
  end
end

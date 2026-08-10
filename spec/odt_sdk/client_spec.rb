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

  let :transport do
    Class.new do
      attr_reader :requests

      def initialize
        @requests = []
      end

      def post(url, payload)
        @requests << { url: url, payload: payload }

        { status: 200, body: { 'result' => { 'code' => '0' } } }
      end
    end.new
  end

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

  def attempt_request
    client.request notify
  rescue OdtSdk::ConfigurationError
    nil
  end
end

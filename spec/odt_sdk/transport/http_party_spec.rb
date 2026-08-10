# frozen_string_literal: true

require 'odt_sdk'

RSpec.describe OdtSdk::Transport::HttpParty do
  subject(:transport) { described_class.new client: client }

  let(:url) { 'https://smsapi.odt.com.mx/sendsms' }
  let(:payload) { { security: { partner_id: 'ODT_OTP' }, notify: { number: '5500000010' } } }
  let(:api_response) { Struct.new(:code, :parsed_response).new(200, { 'result' => { 'code' => '0' } }) }
  let(:client) { class_double ::HTTParty, post: api_response }
  let(:json_content_type) { hash_including headers: hash_including('Content-Type' => 'application/json') }
  let(:json_accept) { hash_including headers: hash_including('Accept' => 'application/json') }

  describe '#initialize' do
    it 'defaults the timeout to the configuration default' do
      expect(described_class.new.timeout).to eq(OdtSdk::Configuration::DEFAULT_TIMEOUT)
    end

    it 'accepts a custom timeout' do
      expect(described_class.new(timeout: 45).timeout).to eq(45)
    end

    it 'defaults the client to HTTParty' do
      expect(described_class.new.client).to be(::HTTParty)
    end
  end

  describe '#post' do
    it 'posts to the given url' do
      transport.post url, payload

      expect(client).to have_received(:post).with(url, any_args)
    end

    it 'serializes the payload as a JSON body' do
      transport.post url, payload

      expect(client).to have_received(:post).with(anything, hash_including(body: JSON.generate(payload)))
    end

    it 'announces a JSON content type' do
      transport.post url, payload

      expect(client).to have_received(:post).with(anything, json_content_type)
    end

    it 'accepts a JSON response' do
      transport.post url, payload

      expect(client).to have_received(:post).with(anything, json_accept)
    end

    it 'passes its timeout along' do
      described_class.new(timeout: 45, client: client).post url, payload

      expect(client).to have_received(:post).with(anything, hash_including(timeout: 45))
    end

    it 'returns the http status' do
      expect(transport.post(url, payload)[:status]).to eq(200)
    end

    it 'returns the parsed body' do
      expect(transport.post(url, payload)[:body]).to eq({ 'result' => { 'code' => '0' } })
    end

    it 'exposes only status and body' do
      expect(transport.post(url, payload).keys).to contain_exactly(:status, :body)
    end

    it 'never lets the secure_key reach the request' do
      transport.post url, payload

      expect(client).not_to have_received(:post).with(anything, hash_including(body: /secure_key/))
    end
  end

  describe '#post on a network failure' do
    subject(:transport) { described_class.new client: failing_client }

    let(:failing_client) { class_double ::HTTParty }

    it 'wraps a timeout' do
      allow(failing_client).to receive(:post).and_raise(Timeout::Error)

      expect { transport.post url, payload }.to raise_error(OdtSdk::TransportError)
    end

    it 'wraps a DNS failure' do
      allow(failing_client).to receive(:post).and_raise(Socket::ResolutionError)

      expect { transport.post url, payload }.to raise_error(OdtSdk::TransportError)
    end

    it 'wraps a refused connection' do
      allow(failing_client).to receive(:post).and_raise(Errno::ECONNREFUSED)

      expect { transport.post url, payload }.to raise_error(OdtSdk::TransportError)
    end

    it 'wraps an SSL failure' do
      allow(failing_client).to receive(:post).and_raise(OpenSSL::SSL::SSLError)

      expect { transport.post url, payload }.to raise_error(OdtSdk::TransportError)
    end

    it 'wraps an HTTParty failure' do
      allow(failing_client).to receive(:post).and_raise(::HTTParty::UnsupportedURIScheme)

      expect { transport.post url, payload }.to raise_error(OdtSdk::TransportError)
    end

    it 'names the url in the error' do
      allow(failing_client).to receive(:post).and_raise(Timeout::Error)

      expect { transport.post url, payload }.to raise_error(OdtSdk::TransportError, /#{Regexp.escape url}/)
    end

    it 'keeps the underlying cause in the error' do
      allow(failing_client).to receive(:post).and_raise(SocketError, 'getaddrinfo failed')

      expect { transport.post url, payload }.to raise_error(OdtSdk::TransportError, /getaddrinfo failed/)
    end

    it 'is a rescuable OdtSdk::Error' do
      allow(failing_client).to receive(:post).and_raise(Timeout::Error)

      expect { transport.post url, payload }.to raise_error(OdtSdk::Error)
    end
  end
end

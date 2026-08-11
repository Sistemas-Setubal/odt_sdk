# frozen_string_literal: true

require 'odt_sdk'

RSpec.describe OdtSdk::Otp::Manager do
  subject(:manager) { described_class.new client }

  let :configuration do
    OdtSdk::Configuration.new.tap do |config|
      config.partner_id = 'ODT_OTP'
      config.secure_key = 'EXAMPLE'
      config.service_id = 'EXAMPLE_1'
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

  let(:client) { OdtSdk::Client.new configuration, transport: transport }
  let(:number) { '5500000010' }
  let(:sent) { transport.requests.last[:payload][:notify] }

  def send_it(**overrides)
    manager.send_code(**{ number: number, carrier: 1 }.merge(overrides))
  end

  describe 'defaults' do
    it 'keeps codes in a MemoryStore' do
      expect(manager.store).to be_a(OdtSdk::Otp::MemoryStore)
    end

    it 'builds the same store every time' do
      expect(manager.store).to be(manager.store)
    end

    it 'uses the default template' do
      expect(manager.template.text).to eq(OdtSdk::Otp::Template::DEFAULT)
    end

    it 'draws codes of the generator default length' do
      expect(manager.length).to eq(OdtSdk::Otp::Generator::DEFAULT_LENGTH)
    end

    it 'expires codes on the store default ttl' do
      expect(manager.ttl).to eq(OdtSdk::Otp::MemoryStore::DEFAULT_TTL)
    end
  end

  describe '#send_code' do
    it 'sends through the client' do
      send_it

      expect(transport.requests.size).to eq(1)
    end

    it 'sends to the number asked for' do
      send_it

      expect(sent[:number]).to eq(number)
    end

    it 'sends on the carrier asked for' do
      send_it

      expect(sent[:carrier]).to eq('1')
    end

    it 'writes the code into the message body' do
      send_it

      expect(sent[:message]).to eq("Tu codigo de verificacion es #{manager.store.read(number).code}")
    end

    it 'stores the code it sent' do
      send_it

      expect(sent[:message]).to include(manager.store.read(number).code)
    end

    it 'stores a code of the configured length' do
      send_it

      expect(manager.store.read(number).code.length).to eq(4)
    end

    it 'gives the stored code its ttl' do
      now = Time.now
      allow(Time).to receive(:now).and_return(now)
      send_it

      expect(manager.store.read(number).expires_at).to eq(now + 300)
    end

    it 'returns the Response' do
      expect(send_it).to be_a(OdtSdk::Response)
    end

    it 'reports the send succeeded' do
      expect(send_it).to be_success
    end

    it 'signs the request like any other send' do
      send_it

      expect(transport.requests.last[:payload][:security][:partner_id]).to eq('ODT_OTP')
    end

    it 'passes extra fields through to the client' do
      send_it service_id: 'EXAMPLE_2'

      expect(sent[:service_id]).to eq('EXAMPLE_2')
    end

    it 'draws a fresh code on every send' do
      first = send_it && manager.store.read(number).code
      allow(OdtSdk::Otp::Generator).to receive(:numeric).and_return('9999')
      send_it

      expect(manager.store.read(number).code).not_to eq(first)
    end

    it 'replaces the previous code for that number' do
      send_it
      send_it

      expect(sent[:message]).to include(manager.store.read(number).code)
    end
  end

  describe '#send_code with a custom setup' do
    subject :manager do
      described_class.new client, template: template, length: 6, ttl: 60
    end

    let(:template) { OdtSdk::Otp::Template.new '%{code} es tu codigo' }

    it 'renders the custom template' do
      send_it

      expect(sent[:message]).to eq("#{manager.store.read(number).code} es tu codigo")
    end

    it 'draws a code of the custom length' do
      send_it

      expect(manager.store.read(number).code.length).to eq(6)
    end

    it 'applies the custom ttl' do
      now = Time.now
      allow(Time).to receive(:now).and_return(now)
      send_it

      expect(manager.store.read(number).expires_at).to eq(now + 60)
    end

    it 'sends with the encoding the template was built for' do
      expect(described_class.new(client, template: OdtSdk::Otp::Template.new('%{code}', encoding: 2))
        .send_code(number: number, carrier: 1)).to be_success
    end
  end

  describe '#send_code with an accented template' do
    subject(:manager) { described_class.new client, template: template }

    let(:template) { OdtSdk::Otp::Template.new 'Tu código es %{code}', encoding: OdtSdk::Encodings::UCS2 }

    it 'sends the accented body with UCS-2, which would otherwise be refused' do
      send_it

      expect(sent[:message]).to start_with('Tu código es')
    end

    it 'declares the encoding to ODT' do
      send_it

      expect(sent[:encode]).to eq('2')
    end
  end

  describe '#send_code when the send is refused locally' do
    it 'refuses a number that is not ten digits' do
      expect { send_it number: '55' }.to raise_error(ArgumentError, /10 digits/)
    end

    it 'leaves no code behind for a refused number' do
      begin
        send_it number: '55'
      rescue ArgumentError
        nil
      end

      expect(manager.store.read('55')).to be_nil
    end

    it 'never reaches the transport' do
      begin
        send_it carrier: 99
      rescue ArgumentError
        nil
      end

      expect(transport.requests).to be_empty
    end

    it 'refuses to have its message overwritten' do
      expect { send_it message: 'hola' }.to raise_error(ArgumentError, /from the template/)
    end

    it 'stores nothing when the message is overridden' do
      begin
        send_it message: 'hola'
      rescue ArgumentError
        nil
      end

      expect(manager.store.read(number)).to be_nil
    end
  end
end

# frozen_string_literal: true

require 'odt_sdk'

RSpec.describe OdtSdk do
  after { described_class.reset }

  describe 'VERSION' do
    it 'follows semantic versioning' do
      expect(described_class::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end

  describe '.configuration' do
    it 'hands back a Configuration' do
      expect(described_class.configuration).to be_a(OdtSdk::Configuration)
    end

    it 'is the same one every time' do
      expect(described_class.configuration).to be(described_class.configuration)
    end

    it 'starts with the defaults' do
      expect(described_class.configuration.base_url).to eq(OdtSdk::Configuration::DEFAULT_BASE_URL)
    end
  end

  describe '.configure' do
    it 'yields the configuration' do
      described_class.configure { |config| config.partner_id = 'ODT_OTP' }

      expect(described_class.configuration.partner_id).to eq('ODT_OTP')
    end

    it 'returns the configuration so it chains' do
      expect(described_class.configure { |config| config.secure_key = 'EXAMPLE' })
        .to be(described_class.configuration)
    end

    it 'keeps assigning to the same configuration across calls' do
      described_class.configure { |config| config.partner_id = 'ODT_OTP' }
      described_class.configure { |config| config.secure_key = 'EXAMPLE' }

      expect(described_class.configuration.partner_id).to eq('ODT_OTP')
    end

    it 'demands a block, rather than silently doing nothing' do
      expect { described_class.configure }.to raise_error(ArgumentError, /needs a block/)
    end
  end

  describe '.client' do
    before do
      described_class.configure do |config|
        config.partner_id = 'ODT_OTP'
        config.secure_key = 'EXAMPLE'
      end
    end

    it 'hands back a Client' do
      expect(described_class.client).to be_a(OdtSdk::Client)
    end

    it 'is the same one every time' do
      expect(described_class.client).to be(described_class.client)
    end

    it 'is built on the module configuration' do
      expect(described_class.client.configuration).to be(described_class.configuration)
    end

    it 'is rebuilt after configure, so a late change is not ignored' do
      first = described_class.client
      described_class.configure { |config| config.timeout = 45 }

      expect(described_class.client).not_to be(first)
    end

    it 'picks up the change it was rebuilt for' do
      described_class.client
      described_class.configure { |config| config.timeout = 45 }

      expect(described_class.client.transport.timeout).to eq(45)
    end
  end

  describe '.reset' do
    it 'forgets the configuration' do
      described_class.configure { |config| config.partner_id = 'ODT_OTP' }
      described_class.reset

      expect(described_class.configuration.partner_id).to be_nil
    end

    it 'forgets the client' do
      described_class.configure { |config| config.partner_id = 'ODT_OTP' }
      first = described_class.client
      described_class.reset

      expect(described_class.client).not_to be(first)
    end
  end
end

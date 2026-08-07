# frozen_string_literal: true

require 'odt_sdk'

RSpec.describe OdtSdk::Configuration do
  subject(:config) { described_class.new }

  describe 'defaults' do
    it 'leaves partner_id unset' do
      expect(config.partner_id).to be_nil
    end

    it 'leaves secure_key unset' do
      expect(config.secure_key).to be_nil
    end

    it 'leaves service_id unset' do
      expect(config.service_id).to be_nil
    end

    it 'points base_url at the ODT endpoint' do
      expect(config.base_url).to eq(described_class::DEFAULT_BASE_URL)
    end

    it 'sets a timeout' do
      expect(config.timeout).to eq(described_class::DEFAULT_TIMEOUT)
    end

    it 'measures timestamps in milliseconds' do
      expect(config.timestamp_unit).to eq(:milliseconds)
    end

    it 'reads no environment variable of its own' do
      expect(ENV).not_to receive(:fetch)

      described_class.new
    end
  end

  describe 'accessors' do
    it 'writes partner_id' do
      config.partner_id = 'LOCAL_OTP'

      expect(config.partner_id).to eq('LOCAL_OTP')
    end

    it 'writes secure_key' do
      config.secure_key = 'XBYi9RC0'

      expect(config.secure_key).to eq('XBYi9RC0')
    end

    it 'writes service_id' do
      config.service_id = 'OTP_1'

      expect(config.service_id).to eq('OTP_1')
    end

    it 'writes base_url' do
      config.base_url = 'https://staging.example.com'

      expect(config.base_url).to eq('https://staging.example.com')
    end

    it 'writes timeout' do
      config.timeout = 30

      expect(config.timeout).to eq(30)
    end
  end

  describe '#timestamp_unit=' do
    it 'accepts seconds' do
      config.timestamp_unit = :seconds

      expect(config.timestamp_unit).to eq(:seconds)
    end

    it 'normalizes casing and whitespace' do
      config.timestamp_unit = '  SECONDS  '

      expect(config.timestamp_unit).to eq(:seconds)
    end

    it 'rejects an unknown unit' do
      expect { config.timestamp_unit = :fortnights }.to raise_error(OdtSdk::ConfigurationError)
    end

    it 'names the valid units in the error' do
      expect { config.timestamp_unit = :fortnights }
        .to raise_error(OdtSdk::ConfigurationError, /milliseconds, seconds/)
    end

    it 'keeps the previous unit when the assignment is rejected' do
      begin
        config.timestamp_unit = :fortnights
      rescue OdtSdk::ConfigurationError
        nil
      end

      expect(config.timestamp_unit).to eq(:milliseconds)
    end
  end
end

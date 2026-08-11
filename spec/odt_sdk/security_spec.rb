# frozen_string_literal: true

require 'odt_sdk'

RSpec.describe OdtSdk::Security do
  let :configuration do
    OdtSdk::Configuration.new.tap do |config|
      config.partner_id = 'ODT_OTP'
      config.secure_key = 'EXAMPLE'
    end
  end

  describe '#build' do
    subject(:security) { described_class.new configuration }

    let(:block) { security.build time: '1679590064554' }

    it 'carries the partner_id' do
      expect(block[:partner_id]).to eq('ODT_OTP')
    end

    it 'carries the time it was given' do
      expect(block[:time]).to eq('1679590064554')
    end

    it 'hashes that same time' do
      expect(block[:hash]).to eq('3fed04095f9a9b1024e426b1446ddc7f')
    end

    it 'exposes only partner_id, time and hash' do
      expect(block.keys).to contain_exactly(:partner_id, :time, :hash)
    end

    it 'never exposes the secure_key' do
      expect(block.values).not_to include('EXAMPLE')
    end

    it 'generates the time when none is given' do
      expect(security.build[:time]).to match(/\A\d{13}\z/)
    end

    it 'follows the configured timestamp unit' do
      configuration.timestamp_unit = :seconds

      expect(security.build[:time]).to match(/\A\d{10}\z/)
    end

    it 'hashes the time it generated' do
      generated = security.build

      expect(generated[:hash]).to eq(described_class.hash_for(partner_id: 'ODT_OTP',
                                                              time: generated[:time],
                                                              secure_key: 'EXAMPLE'))
    end

    it 'stringifies a numeric time' do
      expect(security.build(time: 1_679_590_064_554)[:time]).to eq('1679590064554')
    end

    it 'rejects a configuration without credentials' do
      configuration.secure_key = nil

      expect { security.build }.to raise_error(OdtSdk::ConfigurationError, /secure_key/)
    end

    it 'reads the configuration back' do
      expect(security.configuration).to be(configuration)
    end
  end

  describe '.timestamp' do
    it 'returns a string' do
      expect(described_class.timestamp).to be_a(String)
    end

    it 'counts milliseconds by default' do
      expect(described_class.timestamp).to match(/\A\d{13}\z/)
    end

    it 'defaults to the configuration default unit' do
      expect(described_class::TIMESTAMP_FORMATS.keys).to include(OdtSdk::Configuration::DEFAULT_TIMESTAMP_UNIT)
    end

    it 'tracks the current time in milliseconds' do
      expect(described_class.timestamp.to_i).to be_within(1000).of((Time.now.to_f * 1000).round)
    end

    it 'counts seconds when asked' do
      expect(described_class.timestamp(:seconds)).to match(/\A\d{10}\z/)
    end

    it 'tracks the current time in seconds' do
      expect(described_class.timestamp(:seconds).to_i).to be_within(1).of(Time.now.to_i)
    end

    it 'normalizes casing and whitespace' do
      expect(described_class.timestamp('  SECONDS  ')).to match(/\A\d{10}\z/)
    end

    it 'rejects an unknown unit' do
      expect { described_class.timestamp(:fortnights) }.to raise_error(OdtSdk::ConfigurationError)
    end

    it 'names the valid units in the error' do
      expect { described_class.timestamp(:fortnights) }
        .to raise_error(OdtSdk::ConfigurationError, /milliseconds, seconds/)
    end
  end

  describe '.secure_compare' do
    it 'accepts two identical codes' do
      expect(described_class.secure_compare('0473', '0473')).to be(true)
    end

    it 'rejects two different codes of the same length' do
      expect(described_class.secure_compare('0473', '0474')).to be(false)
    end

    it 'rejects codes that differ only in the first digit' do
      expect(described_class.secure_compare('0473', '1473')).to be(false)
    end

    it 'rejects codes that differ only in the last digit' do
      expect(described_class.secure_compare('0473', '0472')).to be(false)
    end

    it 'rejects a shorter guess without raising on the length difference' do
      expect(described_class.secure_compare('0473', '04')).to be(false)
    end

    it 'rejects a longer guess without raising on the length difference' do
      expect(described_class.secure_compare('0473', '047300')).to be(false)
    end

    it 'rejects an empty guess' do
      expect(described_class.secure_compare('0473', '')).to be(false)
    end

    it 'rejects a nil guess' do
      expect(described_class.secure_compare('0473', nil)).to be(false)
    end

    it 'keeps a padded code distinct from its unpadded form' do
      expect(described_class.secure_compare('0007', '7')).to be(false)
    end

    it 'compares a numeric guess by its string form' do
      expect(described_class.secure_compare('1234', 1234)).to be(true)
    end

    it 'never falls back to a length check that short circuits' do
      expect { described_class.secure_compare('a', 'a' * 10_000) }.not_to raise_error
    end

    it 'hashes both sides so the digests it compares are the same length' do
      sizes = []
      allow(OpenSSL).to receive(:fixed_length_secure_compare) { |*digests| sizes = digests.map(&:bytesize) }
      described_class.secure_compare 'a', 'a' * 100

      expect(sizes).to eq([32, 32])
    end
  end

  describe '.hash_for' do
    subject :hash do
      described_class.hash_for partner_id: 'ODT_OTP', time: '1679590064554', secure_key: 'EXAMPLE'
    end

    it 'digests partner_id, time and secure_key with MD5' do
      expect(hash).to eq('3fed04095f9a9b1024e426b1446ddc7f')
    end

    it 'returns a lowercase hex digest' do
      expect(hash).to match(/\A[0-9a-f]{32}\z/)
    end

    it 'concatenates partner_id, time and secure_key in that order' do
      swapped = described_class.hash_for partner_id: 'EXAMPLE', time: '1679590064554', secure_key: 'ODT_OTP'

      expect(hash).not_to eq(swapped)
    end

    it 'digests a numeric time as its string form' do
      numeric = described_class.hash_for partner_id: 'ODT_OTP', time: 1_679_590_064_554, secure_key: 'EXAMPLE'

      expect(numeric).to eq(hash)
    end

    it 'changes when the time changes' do
      later = described_class.hash_for partner_id: 'ODT_OTP', time: '1679590064555', secure_key: 'EXAMPLE'

      expect(later).not_to eq(hash)
    end

    it 'changes when the secure_key changes' do
      other = described_class.hash_for partner_id: 'ODT_OTP', time: '1679590064554', secure_key: 'EXAMPLE_2'

      expect(other).not_to eq(hash)
    end
  end
end

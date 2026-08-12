# frozen_string_literal: true

require 'odt_sdk'

RSpec.describe OdtSdk::Otp::RedisStore do
  subject(:store) { described_class.new redis }

  let(:redis) { FakeRedis.new }
  let(:redis_key) { "#{described_class::NAMESPACE}:5500000010" }

  it_behaves_like 'an OTP store'

  describe 'keys' do
    it 'namespaces them so they cannot collide with the rest of the database' do
      store.write '5500000010', '0473'

      expect(redis.hashes.keys).to eq([redis_key])
    end

    it 'honours a custom namespace' do
      described_class.new(redis, namespace: 'myapp:otp').write '5500000010', '0473'

      expect(redis.hashes.keys).to eq(['myapp:otp:5500000010'])
    end
  end

  describe 'the Redis TTL' do
    it 'outlives the logical expiry by the grace period' do
      store.write '5500000010', '0473', ttl: 300

      expect(redis.expiries[redis_key]).to eq(300 + described_class::GRACE)
    end

    it 'is set in the same transaction as the value, so no key is left without one' do
      allow(redis).to receive(:multi).and_call_original
      store.write '5500000010', '0473'

      expect(redis).to have_received(:multi)
    end
  end

  describe 'what actually lands in Redis' do
    def stored
      redis.hashes[redis_key]
    end

    it 'never holds the code in plain text' do
      store.write '5500000010', '0473'

      expect(stored.values).not_to include('0473')
    end

    it 'holds a digest instead' do
      store.write '5500000010', '0473'

      expect(stored['digest']).to match(/\A[0-9a-f]{64}\z/)
    end

    it 'does not let the code be read back out' do
      store.write '5500000010', '0473'

      expect(store.read('5500000010').code).to be_nil
    end

    it 'salts each write, so the same code stores differently' do
      store.write '5500000010', '0473'
      first = stored['digest']
      store.write '5500000010', '0473'

      expect(stored['digest']).not_to eq(first)
    end

    it 'salts across numbers, so equal codes are not obviously equal' do
      store.write '5500000010', '0473'
      store.write '5500000011', '0473'

      expect(redis.hashes["#{described_class::NAMESPACE}:5500000011"]['digest']).not_to eq(stored['digest'])
    end

    it 'keeps the salt alongside, so the digest can be recomputed' do
      store.write '5500000010', '0473'

      expect(stored['salt']).to match(/\A[0-9a-f]{32}\z/)
    end
  end

  describe 'the pepper' do
    it 'changes the digest, so a Redis dump alone cannot be brute forced' do
      described_class.new(redis, pepper: 'app-secret').write '5500000010', '0473'
      peppered = redis.hashes[redis_key]['digest']
      store.write '5500000010', '0473'

      expect(redis.hashes[redis_key]['digest']).not_to eq(peppered)
    end

    it 'still matches the code it was written with' do
      peppered = described_class.new redis, pepper: 'app-secret'
      peppered.write '5500000010', '0473'

      expect(peppered).to be_matches('5500000010', '0473')
    end

    it 'refuses a code written under a different pepper' do
      described_class.new(redis, pepper: 'app-secret').write '5500000010', '0473'

      expect(described_class.new(redis, pepper: 'other-secret')).not_to be_matches('5500000010', '0473')
    end
  end

  describe 'counting server side' do
    let(:sends_key) { "#{redis_key}:sends" }

    it 'increments attempts with HINCRBY, so concurrent guesses cannot lose one' do
      allow(redis).to receive(:hincrby).and_call_original
      store.write '5500000010', '0473'
      store.increment_attempts '5500000010'

      expect(redis).to have_received(:hincrby).with(redis_key, 'attempts', 1)
    end

    it 'increments sends with INCR, so several app processes share one budget' do
      allow(redis).to receive(:incr).and_call_original
      store.record_send '5500000010', window: 900

      expect(redis).to have_received(:incr).with(sends_key)
    end

    it 'keeps the send counter under its own key, apart from the code' do
      store.write '5500000010', '0473'
      store.record_send '5500000010', window: 900

      expect(redis.counters.keys).to eq([sends_key])
    end

    it 'lets Redis roll the window over by expiring the counter' do
      store.record_send '5500000010', window: 900

      expect(redis.expiries[sends_key]).to eq(900)
    end

    it 'sets that expiry only on the first send, so the window does not slide' do
      store.record_send '5500000010', window: 900
      redis.expiries[sends_key] = :untouched
      store.record_send '5500000010', window: 900

      expect(redis.expiries[sends_key]).to eq(:untouched)
    end
  end
end

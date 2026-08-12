# frozen_string_literal: true

class FakeRedis
  attr_reader :hashes, :expiries, :counters

  def initialize
    @hashes = {}
    @counters = {}
    @expiries = {}
  end

  def multi
    yield self
  end

  def del(key)
    @expiries.delete key

    return 0 if @hashes.delete(key).nil?

    1
  end

  def hset(key, fields)
    @hashes[key] = (@hashes[key] || {}).merge fields
  end

  def hgetall(key)
    @hashes.fetch key, {}
  end

  def incr(key)
    @counters[key] = @counters.fetch(key, 0) + 1
  end

  def hincrby(key, field, amount)
    hash = @hashes[key] ||= {}
    hash[field] = (hash[field].to_i + amount).to_s

    hash[field].to_i
  end

  def exists?(key)
    @hashes.key? key
  end

  def expire(key, seconds)
    @expiries[key] = seconds
  end
end

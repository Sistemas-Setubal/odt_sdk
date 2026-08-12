# frozen_string_literal: true

RSpec.shared_examples 'an OTP store' do
  let(:number) { '5500000010' }
  let(:other_number) { '5500000011' }
  let(:now) { Time.now }

  def freeze_clock(at = now)
    allow(Time).to receive(:now).and_return(at)
  end

  describe 'the contract' do
    it 'answers to every method the Manager calls' do
      expect(store).to respond_to(:write, :read, :matches?, :increment_attempts, :delete, :record_send)
    end

    it 'expires codes after five minutes unless told otherwise' do
      expect(described_class::DEFAULT_TTL).to eq(300)
    end
  end

  describe '#write' do
    it 'stores a code that can be matched back' do
      store.write number, '0473'

      expect(store).to be_matches(number, '0473')
    end

    it 'starts with no attempts spent' do
      store.write number, '0473'

      expect(store.read(number).attempts).to eq(0)
    end

    it 'expires on the default ttl' do
      freeze_clock
      store.write number, '0473'

      expect(store.read(number).expires_at).to be_within(0.001).of(now + described_class::DEFAULT_TTL)
    end

    it 'honours a custom ttl' do
      freeze_clock
      store.write number, '0473', ttl: 60

      expect(store.read(number).expires_at).to be_within(0.001).of(now + 60)
    end

    it 'accepts a numeric number as the key' do
      store.write 5_500_000_010, '0473'

      expect(store).to be_matches(number, '0473')
    end

    it 'replaces a code already stored for that number' do
      store.write number, '0473'
      store.write number, '1234'

      expect(store).not_to be_matches(number, '0473')
    end

    it 'matches the code that replaced it' do
      store.write number, '0473'
      store.write number, '1234'

      expect(store).to be_matches(number, '1234')
    end

    it 'resets the attempts when a new code is written' do
      store.write number, '0473'
      store.increment_attempts number
      store.write number, '1234'

      expect(store.read(number).attempts).to eq(0)
    end

    it 'keeps codes for different numbers apart' do
      store.write number, '0473'
      store.write other_number, '1234'

      expect(store).not_to be_matches(number, '1234')
    end

    it 'rejects a ttl of zero' do
      expect { store.write number, '0473', ttl: 0 }.to raise_error(ArgumentError, /positive/)
    end

    it 'rejects a negative ttl' do
      expect { store.write number, '0473', ttl: -60 }.to raise_error(ArgumentError, /positive/)
    end
  end

  describe '#read' do
    it 'is nil for a number never written' do
      expect(store.read(number)).to be_nil
    end

    it 'is not expired inside the ttl' do
      freeze_clock
      store.write number, '0473', ttl: 300
      freeze_clock now + 299

      expect(store.read(number)).not_to be_expired
    end

    it 'is expired exactly at the ttl boundary' do
      freeze_clock
      store.write number, '0473', ttl: 300
      freeze_clock now + 300

      expect(store.read(number)).to be_expired
    end

    it 'is expired once the ttl has passed' do
      freeze_clock
      store.write number, '0473', ttl: 300
      freeze_clock now + 301

      expect(store.read(number)).to be_expired
    end

    it 'still returns an expired entry, so expiry can be told from never sent' do
      freeze_clock
      store.write number, '0473', ttl: 300
      freeze_clock now + 301

      expect(store.read(number)).not_to be_nil
    end
  end

  describe '#matches?' do
    it 'accepts the code that was written' do
      store.write number, '0473'

      expect(store).to be_matches(number, '0473')
    end

    it 'rejects a different code' do
      store.write number, '0473'

      expect(store).not_to be_matches(number, '9999')
    end

    it 'rejects an unpadded guess for a padded code' do
      store.write number, '0007'

      expect(store).not_to be_matches(number, '7')
    end

    it 'rejects anything for a number never written' do
      expect(store).not_to be_matches(number, '0473')
    end

    it 'compares in constant time' do
      allow(OdtSdk::Security).to receive(:secure_compare).and_return(false)
      store.write number, '0473'
      store.matches? number, '0473'

      expect(OdtSdk::Security).to have_received(:secure_compare)
    end
  end

  describe '#increment_attempts' do
    it 'counts an attempt' do
      store.write number, '0473'
      store.increment_attempts number

      expect(store.read(number).attempts).to eq(1)
    end

    it 'counts each attempt' do
      store.write number, '0473'
      3.times { store.increment_attempts number }

      expect(store.read(number).attempts).to eq(3)
    end

    it 'leaves the code alone' do
      store.write number, '0473'
      store.increment_attempts number

      expect(store).to be_matches(number, '0473')
    end

    it 'leaves the expiry alone' do
      freeze_clock
      store.write number, '0473', ttl: 300
      store.increment_attempts number

      expect(store.read(number).expires_at).to be_within(0.001).of(now + 300)
    end

    it 'does nothing for a number never written' do
      expect { store.increment_attempts number }.not_to raise_error
    end

    it 'leaves an unknown number unstored' do
      store.increment_attempts number

      expect(store.read(number)).to be_nil
    end
  end

  describe '#delete' do
    it 'forgets the code' do
      store.write number, '0473'
      store.delete number

      expect(store.read(number)).to be_nil
    end

    it 'stops matching once deleted' do
      store.write number, '0473'
      store.delete number

      expect(store).not_to be_matches(number, '0473')
    end

    it 'is quiet about a number never written' do
      expect { store.delete number }.not_to raise_error
    end

    it 'leaves other numbers alone' do
      store.write number, '0473'
      store.write other_number, '1234'
      store.delete number

      expect(store).to be_matches(other_number, '1234')
    end
  end

  describe '#record_send' do
    it 'counts the first send as one' do
      expect(store.record_send(number, window: 900)).to eq(1)
    end

    it 'counts each send in the window' do
      2.times { store.record_send number, window: 900 }

      expect(store.record_send(number, window: 900)).to eq(3)
    end

    it 'counts per number' do
      3.times { store.record_send number, window: 900 }

      expect(store.record_send(other_number, window: 900)).to eq(1)
    end

    it 'is independent of the stored code' do
      store.write number, '0473'
      store.record_send number, window: 900
      store.delete number

      expect(store.record_send(number, window: 900)).to eq(2)
    end
  end

  describe 'driving the Manager' do
    it 'verifies a code end to end' do
      manager = OdtSdk::Otp::Manager.new nil, store: store
      store.write number, '0473'

      expect(manager.verify(number: number, code: '0473')).to be_ok
    end

    it 'reports a wrong code as a mismatch' do
      manager = OdtSdk::Otp::Manager.new nil, store: store
      store.write number, '0473'

      expect(manager.verify(number: number, code: '9999').reason).to eq(:mismatch)
    end

    it 'consumes the code once accepted' do
      manager = OdtSdk::Otp::Manager.new nil, store: store
      store.write number, '0473'
      manager.verify number: number, code: '0473'

      expect(manager.verify(number: number, code: '0473').reason).to eq(:not_found)
    end
  end
end

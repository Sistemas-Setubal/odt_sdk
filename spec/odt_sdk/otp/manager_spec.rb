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

  let(:transport) { FakeTransport.new }
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

  describe '#verify' do
    def stored_code
      manager.store.read(number).code
    end

    it 'accepts the code that was sent' do
      send_it

      expect(manager.verify(number: number, code: stored_code)).to be_ok
    end

    it 'names that reason ok' do
      send_it

      expect(manager.verify(number: number, code: stored_code).reason).to eq(:ok)
    end

    it 'rejects a different code' do
      send_it

      expect(manager.verify(number: number, code: '9999').reason).to eq(:mismatch)
    end

    it 'rejects the right code for a different number' do
      send_it

      expect(manager.verify(number: '5500000011', code: stored_code).reason).to eq(:not_found)
    end

    it 'reports a number that never asked for a code' do
      expect(manager.verify(number: number, code: '0473').reason).to eq(:not_found)
    end

    it 'rejects an unpadded guess for a padded code' do
      send_it
      allow(manager.store).to receive(:read).and_return(OdtSdk::Otp::Entry.new(code: '0007',
                                                                              expires_at: Time.now + 300))

      expect(manager.verify(number: number, code: '7').reason).to eq(:mismatch)
    end
  end

  describe 'send rate limit' do
    it 'allows five sends per window by default' do
      expect(manager.max_sends).to eq(5)
    end

    it 'uses a fifteen minute window by default' do
      expect(manager.send_window).to eq(900)
    end

    it 'names those defaults in constants' do
      expect([described_class::DEFAULT_MAX_SENDS, described_class::DEFAULT_SEND_WINDOW]).to eq([5, 900])
    end

    it 'lets the fifth send through' do
      4.times { send_it }

      expect(send_it).to be_success
    end

    it 'refuses the sixth' do
      5.times { send_it }

      expect { send_it }.to raise_error(OdtSdk::RateLimitError)
    end

    it 'is a rescuable OdtSdk::Error' do
      5.times { send_it }

      expect { send_it }.to raise_error(OdtSdk::Error)
    end

    it 'names the number in the error' do
      5.times { send_it }

      expect { send_it }.to raise_error(OdtSdk::RateLimitError, /#{number}/)
    end

    it 'carries the limit and window for a retry-after header' do
      5.times { send_it }

      expect { send_it }.to raise_error(an_object_having_attributes(limit: 5, window: 900))
    end

    it 'never reaches the transport once refused' do
      5.times { send_it }
      sent_so_far = transport.requests.size
      begin
        send_it
      rescue OdtSdk::RateLimitError
        nil
      end

      expect(transport.requests.size).to eq(sent_so_far)
    end

    it 'leaves the previous code usable after a refusal' do
      4.times { send_it }
      code = manager.store.read(number).code
      2.times do
        send_it
      rescue OdtSdk::RateLimitError
        nil
      end

      expect(manager.verify(number: number, code: code).reason).to eq(:mismatch)
    end

    it 'counts per number' do
      5.times { send_it }

      expect(manager.send_code(number: '5500000011', carrier: 1)).to be_success
    end

    it 'lets sends through again once the window rolls over' do
      now = Time.now
      allow(Time).to receive(:now).and_return(now)
      5.times { send_it }
      allow(Time).to receive(:now).and_return(now + 901)

      expect(send_it).to be_success
    end

    it 'still refuses just before the window rolls over' do
      now = Time.now
      allow(Time).to receive(:now).and_return(now)
      5.times { send_it }
      allow(Time).to receive(:now).and_return(now + 899)

      expect { send_it }.to raise_error(OdtSdk::RateLimitError)
    end

    it 'honours a custom limit' do
      manager = described_class.new client, max_sends: 1
      manager.send_code number: number, carrier: 1

      expect { manager.send_code number: number, carrier: 1 }.to raise_error(OdtSdk::RateLimitError)
    end

    it 'honours a custom window' do
      manager = described_class.new client, max_sends: 1, send_window: 60
      now = Time.now
      allow(Time).to receive(:now).and_return(now)
      manager.send_code number: number, carrier: 1
      allow(Time).to receive(:now).and_return(now + 61)

      expect(manager.send_code(number: number, carrier: 1)).to be_success
    end
  end

  describe '#valid?' do
    def stored_code
      manager.store.read(number).code
    end

    it 'is true for the code that was sent' do
      send_it

      expect(manager.valid?(number: number, code: stored_code)).to be(true)
    end

    it 'is false for a wrong code' do
      send_it

      expect(manager.valid?(number: number, code: '9999')).to be(false)
    end

    it 'is false when nothing was sent' do
      expect(manager.valid?(number: number, code: '0473')).to be(false)
    end

    it 'is false once the ttl has passed' do
      now = Time.now
      allow(Time).to receive(:now).and_return(now)
      send_it
      code = stored_code
      allow(Time).to receive(:now).and_return(now + 301)

      expect(manager.valid?(number: number, code: code)).to be(false)
    end

    it 'is false once the attempts are spent' do
      send_it
      code = stored_code
      3.times { manager.valid? number: number, code: '9999' }

      expect(manager.valid?(number: number, code: code)).to be(false)
    end

    it 'answers with a plain boolean, not a Result' do
      send_it

      expect(manager.valid?(number: number, code: '9999')).to be_a(FalseClass)
    end

    it 'consumes the code just as verify does' do
      send_it
      code = stored_code
      manager.valid? number: number, code: code

      expect(manager.valid?(number: number, code: code)).to be(false)
    end

    it 'counts a wrong guess just as verify does' do
      send_it
      manager.valid? number: number, code: '9999'

      expect(manager.store.read(number).attempts).to eq(1)
    end
  end

  describe '#verify consumes the code' do
    def stored_code
      manager.store.read(number).code
    end

    it 'forgets the code once it has been accepted' do
      send_it
      manager.verify number: number, code: stored_code

      expect(manager.store.read(number)).to be_nil
    end

    it 'refuses the same code a second time' do
      send_it
      code = stored_code
      manager.verify number: number, code: code

      expect(manager.verify(number: number, code: code).reason).to eq(:not_found)
    end

    it 'is not ok the second time' do
      send_it
      code = stored_code
      manager.verify number: number, code: code

      expect(manager.verify(number: number, code: code)).not_to be_ok
    end

    it 'keeps the code after a wrong guess' do
      send_it
      manager.verify number: number, code: '9999'

      expect(manager.store.read(number)).not_to be_nil
    end

    it 'keeps the code after a lockout, so the reason stays too_many_attempts' do
      send_it
      4.times { manager.verify number: number, code: '9999' }

      expect(manager.verify(number: number, code: '9999').reason).to eq(:too_many_attempts)
    end

    it 'leaves other numbers alone' do
      send_it
      manager.send_code number: '5500000011', carrier: 1
      other = manager.store.read('5500000011').code
      manager.verify number: number, code: stored_code

      expect(manager.store.read('5500000011').code).to eq(other)
    end

    it 'lets a fresh code be sent and accepted after one was consumed' do
      send_it
      manager.verify number: number, code: stored_code
      send_it

      expect(manager.verify(number: number, code: stored_code)).to be_ok
    end
  end

  describe '#verify keeps expired codes readable' do
    it 'does not consume an expired code, so it keeps reporting expired' do
      now = Time.now
      allow(Time).to receive(:now).and_return(now)
      send_it
      code = manager.store.read(number).code
      allow(Time).to receive(:now).and_return(now + 301)
      manager.verify number: number, code: code

      expect(manager.verify(number: number, code: code).reason).to eq(:expired)
    end
  end

  describe '#verify attempt limit' do
    def stored_code
      manager.store.read(number).code
    end

    def guess_wrong(times)
      times.times { manager.verify number: number, code: '9999' }
    end

    it 'allows three guesses by default' do
      expect(manager.max_attempts).to eq(3)
    end

    it 'names that default in a constant' do
      expect(described_class::DEFAULT_MAX_ATTEMPTS).to eq(3)
    end

    it 'still reports a mismatch on the third wrong guess' do
      send_it
      guess_wrong 2

      expect(manager.verify(number: number, code: '9999').reason).to eq(:mismatch)
    end

    it 'locks out on the fourth guess' do
      send_it
      guess_wrong 3

      expect(manager.verify(number: number, code: '9999').reason).to eq(:too_many_attempts)
    end

    it 'refuses even the right code once locked out' do
      send_it
      code = stored_code
      guess_wrong 3

      expect(manager.verify(number: number, code: code).reason).to eq(:too_many_attempts)
    end

    it 'stays locked out on later tries' do
      send_it
      guess_wrong 5

      expect(manager.verify(number: number, code: '9999').reason).to eq(:too_many_attempts)
    end

    it 'counts a wrong guess' do
      send_it
      guess_wrong 1

      expect(manager.store.read(number).attempts).to eq(1)
    end

    it 'stops counting once locked out, so the counter cannot run away' do
      send_it
      guess_wrong 10

      expect(manager.store.read(number).attempts).to eq(3)
    end

    it 'still accepts the right code after two wrong ones' do
      send_it
      code = stored_code
      guess_wrong 2

      expect(manager.verify(number: number, code: code)).to be_ok
    end

    it 'keeps the count per number' do
      send_it
      guess_wrong 3
      manager.send_code number: '5500000011', carrier: 1

      expect(manager.verify(number: '5500000011', code: '9999').reason).to eq(:mismatch)
    end

    it 'clears the count when a new code is sent' do
      send_it
      guess_wrong 3
      send_it

      expect(manager.verify(number: number, code: '9999').reason).to eq(:mismatch)
    end

    it 'checks the limit before comparing, so a lockout leaks nothing about the code' do
      send_it
      code = stored_code
      guess_wrong 3
      allow(OdtSdk::Security).to receive(:secure_compare)
      manager.verify number: number, code: code

      expect(OdtSdk::Security).not_to have_received(:secure_compare)
    end

    it 'honours a custom limit' do
      manager = described_class.new client, max_attempts: 1
      manager.send_code number: number, carrier: 1
      manager.verify number: number, code: '9999'

      expect(manager.verify(number: number, code: '9999').reason).to eq(:too_many_attempts)
    end

    it 'refuses a limit of zero, which would lock every code out' do
      expect { described_class.new(client, max_attempts: 0).max_attempts }
        .to raise_error(ArgumentError, /positive integer/)
    end

    it 'refuses a limit that is not an integer' do
      expect { described_class.new(client, max_attempts: '3').max_attempts }
        .to raise_error(ArgumentError, /"3"/)
    end
  end

  describe '#verify once the ttl has passed' do
    def send_and_age(seconds)
      now = Time.now
      allow(Time).to receive(:now).and_return(now)
      send_it
      code = manager.store.read(number).code
      allow(Time).to receive(:now).and_return(now + seconds)

      code
    end

    it 'still accepts the code one second before it expires' do
      code = send_and_age 299

      expect(manager.verify(number: number, code: code)).to be_ok
    end

    it 'refuses the code once the ttl has passed' do
      code = send_and_age 301

      expect(manager.verify(number: number, code: code).reason).to eq(:expired)
    end

    it 'refuses it exactly at the ttl boundary' do
      code = send_and_age 300

      expect(manager.verify(number: number, code: code).reason).to eq(:expired)
    end

    it 'tells expiry apart from never having asked for a code' do
      send_and_age 301

      expect(manager.verify(number: number, code: '9999').reason).to eq(:expired)
    end

    it 'checks expiry before comparing, so a wrong guess on a dead code also reads expired' do
      send_and_age 301

      expect(manager.verify(number: number, code: 'whatever').reason).to eq(:expired)
    end

    it 'honours a custom ttl' do
      manager = described_class.new client, ttl: 60
      now = Time.now
      allow(Time).to receive(:now).and_return(now)
      manager.send_code number: number, carrier: 1
      allow(Time).to receive(:now).and_return(now + 61)

      expect(manager.verify(number: number, code: '9999').reason).to eq(:expired)
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

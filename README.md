# odt_sdk

Ruby SDK for the ODT API.

## Requirements

Ruby `>= 3.4.0` (pinned to 3.4.3 in `.ruby-version`).

## Configuration

`OdtSdk::Configuration` holds the credentials and connection settings. Build
one and assign what you need:

```ruby
require 'odt_sdk'

config = OdtSdk::Configuration.new
config.partner_id = 'ODT_OTP'
config.secure_key = 'your-secure-key'
config.service_id = 'EXAMPLE_1'
```

| Setting          | Required | Default                        | Notes |
|------------------|----------|--------------------------------|-------|
| `partner_id`     | yes      | —                              | Partner identifier issued by ODT. |
| `secure_key`     | yes      | —                              | Signs the request hash. Never sent in the payload, never commit it. |
| `service_id`     | no       | —                              | Partner application identifier. |
| `base_url`       | no       | `https://smsapi.odt.com.mx`    | Override to point at another host. |
| `timeout`        | no       | `10`                           | Request timeout in seconds. |
| `timestamp_unit` | no       | `:milliseconds`                | `:milliseconds` or `:seconds`. |


A Rails initializer looks like this:

```ruby
# config/initializers/odt_sdk.rb
ODT_CONFIG = OdtSdk::Configuration.new.tap do |config|
  config.partner_id = Rails.application.credentials.dig(:odt, :partner_id)
  config.secure_key = Rails.application.credentials.dig(:odt, :secure_key)
  config.service_id = 'EXAMPLE_1'
  config.timeout    = 15
end
```

Each `Configuration` is an independent object, so a single process can hold
several — one per environment or per partner.

### Validation

`validate!` requires `partner_id` and `secure_key`, and returns the
configuration so it chains. Blank strings count as missing, since an unset
environment variable usually arrives as `""` rather than `nil`:

```ruby
config.validate!
# => OdtSdk::ConfigurationError: Missing ODT credentials: partner_id, secure_key.
#    Assign them on the configuration before sending requests.

config.validate   # => false, never raises
```

Every missing credential is named at once, so you fix them in a single pass.

`timestamp_unit` is validated on assignment instead — it normalizes casing and
whitespace, and rejects anything outside the two valid units:

```ruby
config.timestamp_unit = '  SECONDS  '   # => :seconds
config.timestamp_unit = :minutes
# => OdtSdk::ConfigurationError: Unknown timestamp unit :minutes.
#    Valid units: milliseconds, seconds.
```

The default is milliseconds: ODT's manual shows a 13-digit timestamp even
though its prose says seconds. This is still open with ODT — the request hash
is computed over the same timestamp string that gets sent, so the wrong unit
makes every request fail validation on their side.

## Timestamp

`OdtSdk::Security.timestamp` reads the clock and returns the value as a string,
ready to be sent and hashed:

```ruby
OdtSdk::Security.timestamp             # => "1679590064554"  (13 digits, ms)
OdtSdk::Security.timestamp(:seconds)   # => "1679590064"     (10 digits)
```

The unit defaults to milliseconds and accepts the same two values as
`timestamp_unit`, with the same normalization and the same
`ConfigurationError` on anything else:

```ruby
OdtSdk::Security.timestamp('  SECONDS  ')   # => "1679590064"
OdtSdk::Security.timestamp(:minutes)
# => OdtSdk::ConfigurationError: Unknown timestamp unit :minutes.
#    Valid units: milliseconds, seconds.
```

Pass your configuration's unit to keep both in step:

```ruby
OdtSdk::Security.timestamp(config.timestamp_unit)
```

## Request hash

Every ODT request carries a `security` block signed with MD5 over
`partner_id + time + secure_key`, in that exact order.
`OdtSdk::Security.hash_for` computes it:

```ruby
OdtSdk::Security.hash_for(
  partner_id: 'ODT_OTP',
  time: '1679590064554',
  secure_key: 'EXAMPLE'
)
# => "3fed04095f9a9b1024e426b1446ddc7f"
```

The `secure_key` only feeds the digest — it never travels in the payload. The
`time` must be the very same string that goes out in the request, so generate
both together rather than reading the clock twice.

## Constant-time comparison

`OdtSdk::Security.secure_compare` compares two secrets without leaking, through
timing, how much of one matched:

```ruby
OdtSdk::Security.secure_compare('0473', '0473')  # => true
OdtSdk::Security.secure_compare('0473', '1473')  # => false
```

Use it for OTP codes and request hashes — anything an attacker gets to guess at
repeatedly. Ruby's `==` returns as soon as it finds a differing byte, so a wrong
guess that shares a prefix takes measurably longer to reject than one that
differs immediately. Over enough attempts that difference recovers the secret one
character at a time.

Both sides are hashed with SHA-256 before comparing. That is not for secrecy — it
is what makes the two inputs the same length, since
`OpenSSL.fixed_length_secure_compare` raises on mismatched lengths, and a length
check before comparing would leak the length itself.

Measured over 300k comparisons against `"0473"`:

| Guess | `secure_compare` | `==` |
|---|---|---|
| differs at the first digit | 1253 ns | 35 ns |
| differs at the last digit  | 1252 ns | 35 ns |
| identical                  | 1249 ns | 35 ns |

`==` is far faster, and that is exactly the problem: it is fast in a way that
depends on the secret. `secure_compare` costs about 1.2 µs whatever you feed it.

## Security block

`OdtSdk::Security#build` does exactly that: it takes a configuration, reads the
clock once and returns the block every ODT request carries.

```ruby
security = OdtSdk::Security.new(config)

security.build
# => { partner_id: "ODT_OTP",
#      time: "1679590064554",
#      hash: "3fed04095f9a9b1024e426b1446ddc7f" }
```

The `time` follows the configuration's `timestamp_unit`, and the `hash` is
always computed over the `time` in the same block. Pass `time:` to pin it —
useful in tests and when replaying a request:

```ruby
security.build(time: '1679590064554')
```

`build` calls `validate!` first, so a configuration missing its credentials
raises `ConfigurationError` instead of signing with a blank key.

## Sending

`OdtSdk::Client#send_sms` is the whole flow in one call — it builds the `notify`
block, signs the request and parses the reply:

```ruby
client = OdtSdk::Client.new(config)

response = client.send_sms(
  number: '5500000010',
  message: 'Tu codigo es 123456',
  carrier: 1
)

response.code  # => "0"
```

`service_id` falls back to the one on the configuration; pass it explicitly to
send through a different one. `number`, `message` and `carrier` are required and
raise `ArgumentError` when missing — as does any field ODT does not define, so a
typo fails locally instead of coming back as a `101`.

`encode:` is accepted here too and forwarded to the `notify` block:

```ruby
client.send_sms(number: '5500000010', message: 'Tu codigo de verificacion es 123456',
                carrier: OdtSdk::Carriers::TELCEL, encode: OdtSdk::Encodings::UCS2)
```

### Raising instead of checking

`send_sms` always returns a `Response`, whatever ODT answered. `send_sms!` sends
the same request and raises `OdtSdk::ApiError` when the message did not go out:

```ruby
client.send_sms!(number: '5500000010', message: 'Tu codigo es 123456', carrier: 1)
# => OdtSdk::ApiError: ODT answered code "101" (HTTP 200): "malformed".
```

The error carries the parts you need to react or log, including the whole
response:

```ruby
rescue OdtSdk::ApiError => e
  e.code         # => "101"
  e.api_message  # => "malformed"
  e.response     # => the OdtSdk::Response, with http_status and body
end
```

It raises on anything `failure?` covers, **including a queued message** — see the
Response section for why. If deferred delivery is a normal outcome for you, use
`send_sms` and branch on `queued?` instead of rescuing.

`request!` is the same pairing for the lower level entry point.

`#request` is the lower level entry point, for a payload you assembled yourself:

```ruby
client.request(notify: message.to_notify)
# => #<OdtSdk::Response http_status=200 code="0" message="success sms sent" id="1">
```

Every payload it sends gets a freshly signed `security` block merged in, so no
caller can send an unsigned — or stale — request.

The block is built per request, never memoized, because the `hash` is only valid
for the `time` it was computed with. It is merged last, so a `security` key in
the caller's payload is replaced rather than honoured. And `Security#build` runs
`validate!` first — a configuration missing credentials raises
`ConfigurationError` before the transport is ever touched.

`send_url` derives from the configured `base_url`:

```ruby
client.send_url  # => "https://smsapi.odt.com.mx/sendsms"
```

The transport defaults to `Transport::HttpParty`, built lazily on first use with
the configured timeout, so HTTParty is never loaded in a process that injects its
own transport:

```ruby
OdtSdk::Client.new(config, transport: fake)
```

## Notify block

The other half of every send is the `notify` block. `OdtSdk::Message` holds the
four fields ODT requires and serializes them:

```ruby
message = OdtSdk::Message.new(
  service_id: 'EXAMPLE_1',
  number: '5500000010',
  carrier: 1,
  message: 'Tu codigo es 123456'
)

message.to_notify
# => { service_id: "EXAMPLE_1", number: "5500000010", carrier: "1", message: "Tu codigo es 123456" }
```

The keyword names match the manual's field names exactly, so the block reads the
same in Ruby as it does in the ODT spec. ODT expects every field as a string, so
`to_notify` stringifies them — a numeric `carrier` or `number` serializes
correctly either way.

`service_id`, `number`, `carrier` and `message` are required; a missing one — or
a field ODT does not define — raises `ArgumentError`.

### Validation

`to_notify` validates before it serializes, so an invalid message never reaches
the network — it raises `ArgumentError` locally instead of coming back as a `101`
you have to decode:

```ruby
OdtSdk::Message.new(..., number: '55 0000 0010').to_notify
# => ArgumentError: Invalid number "55 0000 0010". ODT expects an MSISDN of 10 digits.

OdtSdk::Message.new(..., carrier: 99).to_notify
# => ArgumentError: Invalid carrier 99. Valid carriers: 0, 1, 2, 3.
```

The rules are ODT's: `number` is exactly 10 digits, `carrier` is one of
`Carriers::ALL`, `encode` — when given — is one of `Encodings::ALL`, and
`service_id` and `message` cannot be blank. The message must also fit the
encoding's character limit:

```ruby
OdtSdk::Message.new(..., message: 'a' * 161).to_notify
# => ArgumentError: message is 161 characters, over the 160 this encoding allows.
#    Shorten it, and note UCS-2 only allows 70.
```

160 characters under `REPLACING` and `GSM`, 70 under `UCS2`. The SDK refuses an
over-long message rather than letting ODT decide — the manual does not say
whether it truncates or rejects, and a truncated OTP is one whose code got cut
off the end.

The number check is strict rather than forgiving — `+525500000010` and
`55 0000 0010` are both rejected instead of being stripped down to 10 digits.
Normalizing on your side is a decision about your data; guessing at it here would
mean sending a number you never wrote.

`validate!` returns the message so it chains, and `validate` answers the same
question as a boolean without raising:

```ruby
message.validate   # => false
message.validate!  # => ArgumentError
```

### Optional fields

`encode` is optional and is **left out of the payload entirely** when you do not
pass it, rather than sent empty. ODT answers `101` to an empty field value, so an
omitted field and a blank one are not the same thing.

```ruby
OdtSdk::Message.new(
  service_id: 'EXAMPLE_1',
  number: '5500000010',
  carrier: OdtSdk::Carriers::TELCEL,
  message: 'Tu codigo de verificacion es 123456',
  encode: OdtSdk::Encodings::UCS2
).to_notify
# => { service_id: "EXAMPLE_1", number: "5500000010", carrier: "1",
#      message: "Tu codigo de verificacion es 123456", encode: "2" }
```

## Carriers and encodings

The values ODT documents, as constants:

```ruby
OdtSdk::Carriers::DEFAULT   # => 0, unknown carrier
OdtSdk::Carriers::TELCEL    # => 1
OdtSdk::Carriers::MOVISTAR  # => 2
OdtSdk::Carriers::ATT       # => 3

OdtSdk::Carriers.valid?(1)        # => true
OdtSdk::Carriers.valid?('telcel') # => false
```

```ruby
OdtSdk::Encodings::REPLACING  # => 0, 160 chars, illegal characters replaced
OdtSdk::Encodings::GSM        # => 1, strict GSM
OdtSdk::Encodings::UCS2       # => 2, 70 chars, accents and unicode allowed
```

`valid?` takes the number either way, so `1` and `"1"` both pass — it is the
same check whether the value came from your code or from a form field. A leading
zero reads as base ten, so `"010"` is rejected rather than quietly becoming `8`.

Accents are illegal under `REPLACING`, the default, and ODT replaces them
silently — `código` is delivered as something else, and the reply is still a
`"0"`. The SDK refuses the message instead, so the substitution never happens
behind your back:

```ruby
client.send_sms(number: '5500000010', message: 'Tu código es 123456', carrier: 1)
# => ArgumentError: message carries characters this encoding replaces.
#    Write it without accents, or send it with Encodings::UCS2.
```

Two ways out: write the copy without accents ("codigo", "verificacion"), or pass
`encode: OdtSdk::Encodings::UCS2`, which allows accents and unicode but drops the
limit to 70 characters.

`Encodings.supports?` is the check on its own, if you want to branch before
sending:

```ruby
OdtSdk::Encodings.supports?('Tu codigo', OdtSdk::Encodings::REPLACING)  # => true
OdtSdk::Encodings.supports?('Tu código', OdtSdk::Encodings::REPLACING)  # => false
OdtSdk::Encodings.supports?('Tu código', OdtSdk::Encodings::UCS2)       # => true
```

The rule is deliberately conservative: anything outside ASCII is refused unless
the encoding is UCS-2. Strict GSM does define a handful of accented characters,
so a few of them are rejected here that GSM itself would carry — but ODT's manual
says it replaces accents under encoding `0`, and a message that arrives mangled
is worse than one that never left.

## Transport

HTTP lives behind a transport: any object responding to `#post(url, payload)`
and returning `{ status:, body: }`. `OdtSdk::Transport::HttpParty` is the real
one, a JSON POST over HTTParty.

```ruby
transport = OdtSdk::Transport::HttpParty.new(timeout: config.timeout)

transport.post('https://smsapi.odt.com.mx/sendsms', security: {}, notify: {})
# => { status: 200, body: { "result" => { "code" => "0", "message" => "success", "id" => "1" } } }
```

The payload is serialized with `JSON.generate` and sent with
`Content-Type: application/json` and `Accept: application/json`. `status` is the
HTTP status; `body` is HTTParty's parsed response — a Hash for JSON replies, the
raw String otherwise.

`require "httparty"` lives inside that file alone, and Zeitwerk only loads it
when the constant is first referenced. Everything else in the SDK loads and runs
without HTTParty present.

Network failures — timeouts, DNS, refused connections, TLS, HTTParty's own
errors — are wrapped in `OdtSdk::TransportError` naming the url and the
underlying cause, so callers rescue one SDK error instead of the HTTP stack:

```ruby
transport.post(url, payload)
# => OdtSdk::TransportError: POST https://smsapi.odt.com.mx/sendsms failed:
#    SocketError: getaddrinfo failed
```

Swap in your own object to test without the network:

```ruby
fake = Object.new
def fake.post(url, payload) = { status: 200, body: { 'result' => { 'code' => '0' } } }
```

## Response

`Client#request` returns an `OdtSdk::Response` instead of the transport's raw
hash, so `result` is read once and read safely:

```ruby
response = client.request(notify: message.to_notify)

response.http_status  # => 200
response.code         # => "0"
response.message      # => "success sms sent"
response.id           # => "1"
```

`code` is what decides the outcome, not the HTTP status: `"0"` is success, `"1"`
queued, `"2"` a retryable temporary failure, `"101"` malformed. ODT answers `200`
for all of them.

`status` maps the manual's codes onto names you can read and branch on:

| `code`  | `status`             | Meaning |
|---------|----------------------|---------|
| `"0"`   | `:success`           | Sent. |
| `"1"`   | `:queued`            | Accepted, delivery deferred. |
| `"2"`   | `:temporary_failure` | Not delivered, transient — worth retrying. |
| `"101"` | `:malformed`         | Illegal field values; retrying will not help. |
| other   | `:unknown`           | Undocumented code, or a body the SDK could not parse. |

```ruby
case response.status
when :success           then confirm_sent
when :queued            then check_back_later
when :temporary_failure then retry_in(30.seconds)
else                         report response
end
```

Four predicates read the same thing:

```ruby
response.success?    # => status is :success
response.queued?     # => status is :queued, accepted for deferred delivery
response.retryable?  # => status is :temporary_failure, ODT says to try again
response.failure?    # => anything that is not :success
```

`retryable?` is the one worth acting on: `"2"` is the only code the manual tells
you to retry. Retrying a `"101"` sends the same illegal field values again and
gets the same answer.

`failure?` is the complement of `success?`, so **a queued message is both
`queued?` and `failure?`**. That follows ODT's own rule — only `"0"` means the
message went out — and it is the safe default, which matters most for an OTP: a
queued code has not reached the user yet, so treating it as sent leaves them
waiting for a message that never arrived.

Check `queued?` before `failure?` to get the three cases apart:

```ruby
response = client.send_sms(number: number, message: body, carrier: carrier)

return deliver_later if response.queued?
raise DeliveryFailed, response.message if response.failure?

confirm_sent
```

A body the SDK could not parse is a failure too: `code` is `nil`, so `success?`
is `false`. A gateway error page never reads as a successful send.

The body is normalized on read, whether it arrives as a Hash or as a JSON string,
and symbol keys are accepted alongside string ones. A body that is not JSON at
all — an HTML error page from a proxy, an empty body on a gateway timeout — never
raises: `code`, `message` and `id` come back `nil` and `result` is `{}`.

```ruby
response = OdtSdk::Response.new(status: 502, body: '<html>502 Bad Gateway</html>')

response.code         # => nil
response.http_status  # => 502
response.body         # => "<html>502 Bad Gateway</html>"
```

`body` always holds the untouched original, so a response the SDK could not make
sense of is still there to log.

## OTP codes

`OdtSdk::Otp::Generator.numeric` draws a code with `SecureRandom`:

```ruby
OdtSdk::Otp::Generator.numeric     # => "0473"
OdtSdk::Otp::Generator.numeric(6)  # => "051829"
```

The default is **4 digits**. The result is always a String of exactly that
length — a draw of `7` comes back as `"0007"`, never `"7"`. That matters because
the code is compared against what the user typed, and `"0007" != "7"`.

`SecureRandom` rather than `rand`: `rand` is seeded predictably enough that an
attacker who sees a few codes can narrow the next one.

The length must be a positive integer; anything else raises `ArgumentError`
instead of quietly producing a code of the wrong size.

### Message template

`OdtSdk::Otp::Template` holds the copy the code goes into:

```ruby
OdtSdk::Otp::Template.new.render('0473')
# => "Tu codigo de verificacion es 0473"

OdtSdk::Otp::Template.new('%{code} es tu codigo, no lo compartas').render('0473')
# => "0473 es tu codigo, no lo compartas"
```

`%{code}` is where the code lands, and it is substituted literally rather than
through `format`, so a `%` elsewhere in your copy ("50% de descuento") is left
alone instead of blowing up as a malformed format string.

A template without `%{code}` is refused at construction:

```ruby
OdtSdk::Otp::Template.new('Tu codigo de verificacion')
# => ArgumentError: An OTP template must carry the %{code} placeholder,
#    otherwise the code never reaches the user.
```

That check exists because the failure it prevents is invisible: the SMS sends
fine, ODT answers `"0"`, and the user simply never gets a code.

The default copy is written **without accents** on purpose — under the default
encoding ODT replaces them. A template that carries accents is refused when you
build it, so the problem surfaces at boot rather than on the first code you try
to send:

```ruby
OdtSdk::Otp::Template.new('Tu código es %{code}')
# => ArgumentError: An OTP template carries characters this encoding replaces.
#    Write it without accents, or build it with encoding: Encodings::UCS2.

OdtSdk::Otp::Template.new('Tu código es %{code}', encoding: OdtSdk::Encodings::UCS2)
# => works — send with the matching encode:
```

The `encoding:` you build the template with is the one you must send with. They
are checked in both places: here against the copy, and again in `Message` against
the finished body.

### Storing the code

`OdtSdk::Otp::MemoryStore` keeps the code against the phone number, with a TTL:

```ruby
store = OdtSdk::Otp::MemoryStore.new

store.write('5500000010', '0473')             # expires in 300 seconds
store.write('5500000010', '0473', ttl: 60)

entry = store.read('5500000010')
entry.code        # => "0473"
entry.attempts    # => 0
entry.expired?    # => false

store.increment_attempts('5500000010')
store.delete('5500000010')                    # consume it, one use only
```

Six methods make up the whole store interface — `write`, `read`, `matches?`,
`increment_attempts`, `delete` and `record_send`. Anything answering to them can
be swapped in.

That interface is executable, not just described: `spec/support/shared_examples/otp_store.rb`
holds the contract, and both stores run it.

```ruby
RSpec.describe MyStore do
  subject(:store) { described_class.new }

  it_behaves_like 'an OTP store'
end
```

Point it at your own store and you find out whether it really is a drop-in.

**`read` returns expired entries rather than hiding them.** Verification needs to
tell "your code ran out" apart from "you never asked for one", and those are the
same answer if expiry returns `nil`. The entry knows whether it is `expired?`; the
caller decides what that means.

Entries are immutable — `increment_attempts` swaps in a new one rather than
mutating in place — and every operation is behind a mutex, so a threaded server
counts attempts correctly instead of losing some to a race.

Expired entries stick around for an hour so they keep reporting as expired, then
get swept on the next write. Nothing is stored on disk and nothing survives a
restart: this is a single-process store, and a code written by one Puma worker is
invisible to the next. Production with more than one process needs the Redis
store.

The code is held in plain text. That is fine for a value that lives 300 seconds
in one process's memory; a shared store is a different question.

#### Redis

`OdtSdk::Otp::RedisStore` answers to the same four methods and swaps straight in:

```ruby
manager = OdtSdk::Otp::Manager.new(client, store: OdtSdk::Otp::RedisStore.new(Redis.new))
```

The Redis client is injected, never required — the SDK does not depend on the
`redis` gem and never opens a connection of its own. Anything answering to
`multi`, `del`, `hset`, `hgetall`, `hincrby`, `exists?` and `expire` works,
including a connection pool wrapper or a test double.

Keys are namespaced (`odt_sdk:otp:<number>` by default, override with
`namespace:`) so they cannot collide with the rest of your database.

**The Redis TTL is deliberately longer than the code's.** The key lives for the
code's TTL plus an hour, and expiry is judged from the `expires_at` stored inside
it. If Redis reclaimed the key at the logical expiry, `read` would return `nil`
and verification could no longer tell `:expired` from `:not_found` — the same
reason `MemoryStore` keeps expired entries around. The Redis TTL is there so
nothing leaks, not to decide expiry.

Attempts are counted with `HINCRBY`, server side. That matters more here than in
memory: with several application processes verifying at once, a read-modify-write
counter would lose increments, and that counter is what caps brute force.

Writes go through `MULTI` so a key is never left without its TTL.

**The code is never stored in plain text.** Redis holds an HMAC-SHA256 digest and
a random 16-byte salt, and the code cannot be read back — `read(...).code` is
`nil` by design. Verification goes through `matches?`, which recomputes the
digest and compares it in constant time:

```
digest      84af11308ddb117b61c975870570d1f61ebfde4412e94f680d187ebdf1d4a347
salt        489b4616c16044a09c3306485201f71a
expires_at  1786493538.1675591
attempts    0
```

Pass a **pepper** — a secret your application holds and Redis never sees:

```ruby
OdtSdk::Otp::RedisStore.new(Redis.new, pepper: Rails.application.credentials.otp_pepper)
```

This is the part that actually protects you, and it is worth being blunt about
why. A 4-digit code has 10,000 possibilities, so salting alone buys very little:
anyone holding a Redis dump can hash all 10,000 candidates against the salt in
milliseconds. A pepper breaks that, because the dump no longer contains
everything needed to compute the digest. Salting still does its job — it stops
identical codes looking identical across numbers and across rewrites — but the
pepper is what makes a leaked snapshot useless.

Without one, treat the hashing as protection against casual exposure — an
`RDB` file, a `KEYS *`, a log line, someone glancing at a dashboard — and not
against an attacker who has the data and wants a specific code.

### Sending a code

`OdtSdk::Otp::Manager` puts the three steps together — draw a code, store it,
send it — reusing `Client#send_sms` for the last one:

```ruby
manager = OdtSdk::Otp::Manager.new(client)

response = manager.send_code(number: '5500000010', carrier: OdtSdk::Carriers::TELCEL)
response.success?  # => true
```

It returns the same `Response` any other send does, so `status`, `queued?` and
`retryable?` all apply.

Every piece is swappable, and the defaults are the ones each piece already
declares:

```ruby
OdtSdk::Otp::Manager.new(
  client,
  store: OdtSdk::Otp::MemoryStore.new,
  template: OdtSdk::Otp::Template.new('%{code} es tu codigo, no lo compartas'),
  length: 6,
  ttl: 60
)
```

The template's `encoding` is sent as the message's `encode`, so a template built
for UCS-2 goes out as UCS-2 and its accents survive. Building the template for
one encoding and sending with another is the mismatch that mangles a code; the
manager removes the chance to get it wrong.

Extra keywords are forwarded to `send_sms` — `service_id:` to send through a
different application, for instance. `message:` is refused: the body comes from
the template, and silently replacing it would send one code and store another.

#### Send rate limit

A number can be sent **5 codes every 15 minutes**. The sixth raises
`OdtSdk::RateLimitError` without touching the network:

```ruby
OdtSdk::Otp::Manager.new(client, max_sends: 3, send_window: 600)
```

```ruby
rescue OdtSdk::RateLimitError => e
  e.number  # => "5500000010"
  e.limit   # => 5
  e.window  # => 900 — enough to build a Retry-After
end
```

This closes the hole the attempt limit leaves open. Three guesses per code is a
tight cap, but without a send limit an attacker just asks for code after code and
gets three fresh guesses each time — 4 digits stops being 10,000 possibilities
and becomes however many codes they can trigger. Capping sends is what makes the
attempt limit mean something. It also stops your ODT bill being someone else's
denial-of-wallet.

Counts are per number and kept in the store, so with Redis several application
processes share one budget rather than each granting its own. The window is
fixed, not sliding: it starts on the first send and resets whole.

A refused send changes nothing else — the previously stored code stays valid until
its own TTL runs out.

One wrinkle worth knowing: the counter is spent before the message is validated,
so a send refused for a bad number or carrier still uses one of the five. That
keeps a malformed retry loop from being free, but it means a bug in your calling
code burns a real user's budget.

The code is stored **before** the send, never after: a response that gets lost in
transit still leaves a code the user can verify. If the send is refused locally —
a bad number, an invalid carrier — the stored code is removed again, so nothing
is left behind for a message that never left the process.

A send that ODT rejects keeps the stored code. It expires on its own, and a `"1"`
means the SMS may still arrive, so deleting it would break the verification that
follows.

### Verifying a code

`verify` answers with a reason, not just a boolean:

```ruby
result = manager.verify(number: '5500000010', code: params[:code])

result.ok?     # => true
result.reason  # => :ok
```

| `reason` | What happened |
|---|---|
| `:ok` | The code matches and is still live. |
| `:mismatch` | Wrong code. |
| `:expired` | The code was right or wrong, but its TTL had already passed. |
| `:too_many_attempts` | The guess limit for that code is spent. |
| `:not_found` | No code stored for that number — never sent, or already swept. |

**Expiry is checked before the code is compared.** A dead code reads `:expired`
whatever the user typed, so verification never reveals that an expired guess
happened to be correct. It also keeps `:expired` distinct from `:not_found`,
which is the difference between "ask for a new code" and "start over" in your UI.

The comparison itself goes through
[`Security.secure_compare`](#constant-time-comparison), so a near-miss guess
takes the same time to reject as a wildly wrong one.

#### Attempt limit

Three wrong guesses spend a code. The fourth call gets `:too_many_attempts`, and
so does every one after it — including one carrying the right code:

```ruby
OdtSdk::Otp::Manager.new(client, max_attempts: 5)
```

This is what makes a short code safe. A 4-digit code is 10,000 possibilities; the
limit is the only thing standing between that and an attacker walking the whole
space. Lengthening the code helps far less than capping the guesses.

Only wrong guesses count. A correct one leaves the counter alone, and the counter
stops at the limit rather than climbing forever. Sending a new code resets it, and
counts are kept per number.

The limit is checked **before** the comparison runs, so a locked-out request never
touches the stored code at all — there is nothing to time and nothing to learn.

#### One use only

A code is consumed the moment it is accepted. Verifying the same code twice gives
`:ok` and then `:not_found`:

```ruby
manager.verify(number: '5500000010', code: '0473').reason  # => :ok
manager.verify(number: '5500000010', code: '0473').reason  # => :not_found
```

Only success consumes. A wrong guess, a lockout and an expired code all leave the
entry in place — a consumed lockout would come back as `:not_found` and quietly
hand the attacker a fresh set of guesses, and a consumed expired code would lose
the distinction that tells your UI to offer a new one.

#### `valid?`

When you only need a yes or no:

```ruby
manager.valid?(number: '5500000010', code: params[:code])  # => true
```

It is `verify(...).ok?` and nothing more, which means **it is not a free
look**: it spends an attempt on a wrong code and consumes the code on a right
one, exactly as `verify` does. Calling it twice with the same correct code
returns `true` then `false`. Reach for `verify` when you need to tell the user
*why* it failed — expired and locked out call for different messages.

## Development

```bash
bundle install
bundle binstubs reek          # generates bin/reek
bin/console                   # IRB with the SDK preloaded

bundle exec rspec             # full suite + SimpleCov coverage gate
bin/rubocop                   # style
bin/rubocop -A                # auto-correct
bin/reek lib                  # code smells (lib only)
```

CI runs `bin/rubocop`, `bin/reek lib` and `bundle exec rspec` as three
independent jobs; the test job fails if coverage drops below 95% line /
90% branch.

## Conventions

- No code comments.
- No ternary operators; use guard clauses / early returns.
- One `expect` per `it` block in specs.
- `# frozen_string_literal: true` at the top of lib files.
- Files are autoloaded by Zeitwerk (`lib/odt_sdk/boot.rb`) — do not add
  `require_relative` for new files, just follow the filename↔constant
  convention.

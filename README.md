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

## Client

`OdtSdk::Client` owns the request. Every payload it sends gets a freshly signed
`security` block merged in, so no caller can send an unsigned — or stale —
request:

```ruby
client = OdtSdk::Client.new(config)

client.request(notify: message.to_notify)
# => #<OdtSdk::Response http_status=200 code="0" message="success sms sent" id="1">
```

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

Accented characters are illegal under the default encoding and get replaced.
Write OTP copy without them ("codigo", "verificacion").

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

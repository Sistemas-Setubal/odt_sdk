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

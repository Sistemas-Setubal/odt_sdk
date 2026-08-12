# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Project skeleton: RuboCop, Reek, RSpec + SimpleCov coverage gate, CI and
  release workflows, Zeitwerk autoloading.
- `OdtSdk::Configuration` holding `partner_id`, `secure_key`, `service_id`,
  `base_url`, `timeout` and `timestamp_unit`, with `validate` / `validate!`.
  Credentials are never read from `ENV` by the SDK: the host application decides
  where they come from.
- `OdtSdk::Security` for the request `security` block — MD5 over
  `partner_id + time + secure_key`, with the timestamp generated alongside the
  hash so the two can never disagree. Millisecond timestamps by default.
- `OdtSdk::Security.secure_compare` for constant-time comparison of codes and
  hashes.
- `OdtSdk::Transport::HttpParty`, a JSON POST behind an injectable transport
  contract (`#post(url, payload)` returning `{ status:, body: }`). HTTParty is
  required only inside that file, so the rest of the SDK loads without it.
  Network failures are wrapped in `OdtSdk::TransportError`.
- `OdtSdk::Message` building the `notify` block, with local validation of
  `number`, `carrier`, `encode`, the message body and its character limit.
  Optional fields are omitted rather than sent empty.
- `OdtSdk::Carriers` and `OdtSdk::Encodings` as the values ODT documents, with
  `valid?`, per-encoding character limits and a `supports?` check that refuses
  accented copy the default encoding would silently replace.
- `OdtSdk::Client` with `send_sms` / `send_sms!` and `request` / `request!`. A
  freshly signed `security` block is merged into every payload.
- `OdtSdk::Response` mapping ODT's codes onto `:success`, `:queued`,
  `:temporary_failure`, `:malformed` and `:unknown`, with `success?`, `queued?`,
  `retryable?` and `failure?`. Bodies that are not JSON never raise.
- `OdtSdk::ApiError` and `OdtSdk::RateLimitError`.
- OTP flow: `Otp::Generator` (SecureRandom, zero padded, 4 digits by default),
  `Otp::Template` with a `%{code}` placeholder validated at construction,
  `Otp::Manager#send_code`, `#verify` and `#valid?`, and `Otp::Result` carrying
  `:ok`, `:mismatch`, `:expired`, `:too_many_attempts` or `:not_found`.
  Codes are single use, capped at 3 guesses and expire after 300 seconds.
- `Otp::MemoryStore` and `Otp::RedisStore` behind one six-method contract,
  exercised by a shared example group. The Redis store keeps codes as salted
  HMAC-SHA256 digests — never in plain text — accepts an application pepper, and
  counts attempts and sends server side so several processes share one budget.
- Sends are capped per number, 5 every 15 minutes by default.
- `OdtSdk.configure`, `OdtSdk.configuration`, `OdtSdk.client` and `OdtSdk.reset`
  for applications that want a single shared setup.

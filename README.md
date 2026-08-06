# odt_sdk

Ruby SDK for the ODT API.

## Requirements

Ruby `>= 3.4.0` (pinned to 3.4.3 in `.ruby-version`).

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

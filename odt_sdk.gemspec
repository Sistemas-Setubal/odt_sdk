require_relative 'lib/odt_sdk/version'

Gem::Specification.new do |spec|
  spec.name = 'odt_sdk'
  spec.version = OdtSdk::VERSION
  spec.authors = ['Local Solutions IT']
  spec.license = 'MIT'

  spec.summary = 'Ruby SDK for the ODT API.'
  spec.description = 'Centralized configuration and authenticated access to the ODT API.'
  spec.homepage = 'https://github.com/Sistemas-Setubal/odt_sdk'
  spec.required_ruby_version = '>= 3.4.0'

  spec.files = Dir['lib/**/*.rb'] + %w[README.md CHANGELOG.md]
  spec.require_paths = ['lib']

  spec.add_dependency 'httparty', '~> 0.24'
  spec.add_dependency 'zeitwerk', '~> 2.6'

  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'
end

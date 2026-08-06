require_relative 'lib/odt_sdk/version'

Gem::Specification.new do |spec|
  spec.name = 'odt_sdk'
  spec.version = OdtSdk::VERSION
  spec.authors = ['Local Solutions IT']

  spec.summary = 'Ruby SDK for the ODT API.'
  spec.description = 'Centralized configuration and authenticated access to the ODT API.'
  spec.required_ruby_version = '>= 3.4.0'

  spec.files = Dir['lib/**/*.rb']
  spec.require_paths = ['lib']

  spec.add_dependency 'httparty', '~> 0.24'
  spec.add_dependency 'zeitwerk', '~> 2.6'

  spec.metadata['rubygems_mfa_required'] = 'true'
end

require 'simplecov'
SimpleCov.start do
  enable_coverage :branch

  skip '/spec/'
  group 'Libraries', '/lib'

  SimpleCov.minimum_coverage line: 95, branch: 90
end

Dir[File.expand_path('support/**/*.rb', __dir__)].each { |file| require file }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end

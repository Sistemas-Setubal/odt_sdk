# frozen_string_literal: true

require 'odt_sdk'

RSpec.describe OdtSdk do
  describe 'VERSION' do
    it 'follows semantic versioning' do
      expect(described_class::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end
end

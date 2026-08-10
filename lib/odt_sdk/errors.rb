# frozen_string_literal: true

module OdtSdk
  class Error < StandardError; end

  class ConfigurationError < Error; end

  class TransportError < Error; end

  class ApiError < Error
    attr_reader :code, :api_message, :response

    def initialize(response)
      @response = response
      @code = response.code
      @api_message = response.message

      super("ODT answered code #{@code.inspect} (HTTP #{response.http_status}): #{@api_message.inspect}.")
    end
  end
end

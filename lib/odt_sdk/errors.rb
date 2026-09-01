# frozen_string_literal: true

module OdtSdk
  class Error < StandardError; end

  class ConfigurationError < Error; end

  class TransportError < Error; end

  class RateLimitError < Error
    attr_reader :number, :limit, :window

    def initialize(number, limit, window)
      @number = number
      @limit = limit
      @window = window

      super("Too many OTP sends for #{number}: #{limit} allowed every #{window} seconds.")
    end
  end

  class BulkError < Error
    attr_reader :result

    def initialize(result)
      @result = result

      super("#{result.failures.size} of #{result.size} bulk messages failed.")
    end
  end

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

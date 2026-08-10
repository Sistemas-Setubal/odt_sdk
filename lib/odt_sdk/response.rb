# frozen_string_literal: true

require 'json'

module OdtSdk
  class Response
    RESULT_KEY = 'result'

    attr_reader :http_status, :body

    def initialize(status:, body:)
      @http_status = status
      @body = body
    end

    def code
      result_field 'code'
    end

    def message
      result_field 'message'
    end

    def id
      result_field 'id'
    end

    def result
      @result ||= extract_result
    end

    def parsed_body
      @parsed_body ||= parse body
    end

    private

    def result_field(key)
      result[key] || result[key.to_sym]
    end

    def extract_result
      candidate = parsed_body[RESULT_KEY] || parsed_body[RESULT_KEY.to_sym]

      return candidate if candidate.is_a? Hash

      {}
    end

    def parse(raw)
      return raw if raw.is_a? Hash

      decoded = JSON.parse raw.to_s

      return decoded if decoded.is_a? Hash

      {}
    rescue JSON::ParserError
      {}
    end
  end
end

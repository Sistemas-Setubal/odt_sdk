# frozen_string_literal: true

require 'httparty'
require 'json'

module OdtSdk
  module Transport
    class HttpParty
      HEADERS = {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      }.freeze

      NETWORK_ERRORS = [
        ::HTTParty::Error,
        Timeout::Error,
        SocketError,
        SystemCallError,
        OpenSSL::SSL::SSLError
      ].freeze

      attr_reader :timeout, :client

      def initialize(timeout: Configuration::DEFAULT_TIMEOUT, client: ::HTTParty)
        @timeout = timeout
        @client = client
      end

      def post(url, payload)
        response = client.post url, body: JSON.generate(payload), headers: HEADERS, timeout: timeout

        { status: response.code, body: response.parsed_response }
      rescue *NETWORK_ERRORS => error
        raise TransportError, "POST #{url} failed: #{error.class}: #{error.message}"
      end
    end
  end
end

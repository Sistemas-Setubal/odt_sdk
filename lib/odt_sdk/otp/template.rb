# frozen_string_literal: true

module OdtSdk
  module Otp
    class Template
      PLACEHOLDER = '%{code}'
      DEFAULT = "Tu codigo de verificacion es #{PLACEHOLDER}"

      attr_reader :text, :encoding

      def initialize(text = DEFAULT, encoding: Encodings::REPLACING)
        @text = text.to_s
        @encoding = encoding

        demand_placeholder
        demand_supported_characters
      end

      def render(code)
        text.gsub(PLACEHOLDER) { code.to_s }
      end

      private

      def demand_supported_characters
        return if Encodings.supports? text, encoding

        raise ArgumentError,
              'An OTP template carries characters this encoding replaces. ' \
              "Write it without accents, or build it with encoding: Encodings::UCS2. Got #{text.inspect}."
      end

      def demand_placeholder
        return if text.include? PLACEHOLDER

        raise ArgumentError,
              "An OTP template must carry the #{PLACEHOLDER} placeholder, " \
              "otherwise the code never reaches the user. Got #{text.inspect}."
      end
    end
  end
end

require_relative 'odt_sdk/boot'

module OdtSdk
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      raise ArgumentError, 'OdtSdk.configure needs a block.' unless block_given?

      yield configuration

      @client = nil

      configuration
    end

    def client
      @client ||= Client.new configuration
    end

    def reset
      @configuration = nil
      @client = nil
    end
  end
end

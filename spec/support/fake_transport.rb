# frozen_string_literal: true

class FakeTransport
  SUCCESS = { 'result' => { 'code' => '0', 'message' => 'success sms sent', 'id' => '1' } }.freeze

  attr_reader :requests

  def initialize(status: 200, body: SUCCESS)
    @status = status
    @body = body
    @requests = []
  end

  def post(url, payload)
    @requests << { url: url, payload: payload }

    { status: @status, body: @body }
  end

  def last_payload
    @requests.last[:payload]
  end

  def last_notify
    last_payload[:notify]
  end

  def last_url
    @requests.last[:url]
  end
end

# frozen_string_literal: true

class FakeTransport
  SUCCESS = { 'result' => { 'code' => '0', 'message' => 'success sms sent', 'id' => '1' } }.freeze
  QUEUED = { 'result' => { 'code' => '1', 'message' => 'queued', 'id' => '2' } }.freeze
  TEMPORARY_FAILURE = { 'result' => { 'code' => '2', 'message' => 'temporary failure', 'id' => '3' } }.freeze
  MALFORMED = { 'result' => { 'code' => '101', 'message' => 'malformed', 'id' => '4' } }.freeze

  attr_reader :requests

  def initialize(status: 200, body: SUCCESS, bodies: {}, errors: {})
    @status = status
    @body = body
    @bodies = bodies
    @errors = errors
    @requests = []
    @mutex = Mutex.new
  end

  def post(url, payload)
    @mutex.synchronize { @requests << { url: url, payload: payload } }

    number = number_in payload

    raise @errors[number] if @errors.key? number

    { status: @status, body: @bodies.fetch(number, @body) }
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

  def numbers
    @requests.map { |request| number_in request[:payload] }
  end

  private

  def number_in(payload)
    notify = payload[:notify] || payload['notify']

    return nil unless notify.is_a? Hash

    (notify[:number] || notify['number']).to_s
  end
end

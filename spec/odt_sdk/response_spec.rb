# frozen_string_literal: true

require 'odt_sdk'

RSpec.describe OdtSdk::Response do
  subject(:response) { described_class.new status: 200, body: body }

  let(:body) { { 'result' => { 'code' => '0', 'message' => 'success sms sent', 'id' => '1' } } }

  describe 'a parsed hash body' do
    it 'reads the http status' do
      expect(response.http_status).to eq(200)
    end

    it 'reads the code' do
      expect(response.code).to eq('0')
    end

    it 'reads the message' do
      expect(response.message).to eq('success sms sent')
    end

    it 'reads the id' do
      expect(response.id).to eq('1')
    end

    it 'keeps the body untouched' do
      expect(response.body).to be(body)
    end

    it 'exposes the result block' do
      expect(response.result).to eq('code' => '0', 'message' => 'success sms sent', 'id' => '1')
    end
  end

  describe '#status' do
    def response_with(code)
      described_class.new status: 200, body: { 'result' => { 'code' => code } }
    end

    it 'names zero success' do
      expect(response_with('0').status).to eq(:success)
    end

    it 'names one queued' do
      expect(response_with('1').status).to eq(:queued)
    end

    it 'names two a temporary failure' do
      expect(response_with('2').status).to eq(:temporary_failure)
    end

    it 'names 101 malformed' do
      expect(response_with('101').status).to eq(:malformed)
    end

    it 'names a code ODT does not document unknown' do
      expect(response_with('999').status).to eq(:unknown)
    end

    it 'names a missing code unknown' do
      expect(described_class.new(status: 502, body: nil).status).to eq(:unknown)
    end

    it 'names a numeric code the same as its string' do
      expect(response_with(101).status).to eq(:malformed)
    end
  end

  describe '#retryable?' do
    def response_with(code)
      described_class.new status: 200, body: { 'result' => { 'code' => code } }
    end

    it 'is true for the temporary failure ODT says to retry' do
      expect(response_with('2')).to be_retryable
    end

    it 'is false for a malformed request, which retrying will not fix' do
      expect(response_with('101')).not_to be_retryable
    end

    it 'is false for a success' do
      expect(response_with('0')).not_to be_retryable
    end
  end

  describe 'status codes' do
    def response_with(code)
      described_class.new status: 200, body: { 'result' => { 'code' => code } }
    end

    it 'reads zero as success' do
      expect(response_with('0')).to be_success
    end

    it 'does not call a success a failure' do
      expect(response_with('0')).not_to be_failure
    end

    it 'does not call a success queued' do
      expect(response_with('0')).not_to be_queued
    end

    it 'reads one as queued' do
      expect(response_with('1')).to be_queued
    end

    it 'does not call a queued message a success' do
      expect(response_with('1')).not_to be_success
    end

    it 'counts a queued message as a failure, following ODT rule' do
      expect(response_with('1')).to be_failure
    end

    it 'reads two as a failure' do
      expect(response_with('2')).to be_failure
    end

    it 'reads a malformed request as a failure' do
      expect(response_with('101')).to be_failure
    end

    it 'reads an undocumented code as a failure' do
      expect(response_with('999')).to be_failure
    end

    it 'tolerates a numeric code' do
      expect(response_with(0)).to be_success
    end

    it 'treats an unparsable body as a failure' do
      expect(described_class.new(status: 502, body: '<html>bad gateway</html>')).to be_failure
    end

    it 'never reads an unparsable body as a success' do
      expect(described_class.new(status: 200, body: nil)).not_to be_success
    end
  end

  describe 'a JSON string body' do
    let(:body) { '{"result":{"code":"101","message":"malformed","id":null}}' }

    it 'parses the code' do
      expect(response.code).to eq('101')
    end

    it 'parses the message' do
      expect(response.message).to eq('malformed')
    end

    it 'keeps the raw string as the body' do
      expect(response.body).to eq(body)
    end
  end

  describe 'a symbol keyed body' do
    let(:body) { { result: { code: '2', message: 'temporary failure', id: '7' } } }

    it 'reads the code' do
      expect(response.code).to eq('2')
    end

    it 'reads the id' do
      expect(response.id).to eq('7')
    end
  end

  describe 'a body that is not JSON' do
    subject(:response) { described_class.new status: 502, body: body }

    let(:body) { '<html>502 Bad Gateway</html>' }

    it 'does not raise' do
      expect { response.code }.not_to raise_error
    end

    it 'has no code' do
      expect(response.code).to be_nil
    end

    it 'still reports the http status' do
      expect(response.http_status).to eq(502)
    end

    it 'keeps the raw body for inspection' do
      expect(response.body).to eq('<html>502 Bad Gateway</html>')
    end
  end

  describe 'an empty body' do
    let(:body) { nil }

    it 'does not raise' do
      expect { response.code }.not_to raise_error
    end

    it 'has an empty result' do
      expect(response.result).to eq({})
    end
  end

  describe 'a body without a result block' do
    let(:body) { { 'error' => 'unauthorized' } }

    it 'has no code' do
      expect(response.code).to be_nil
    end

    it 'has an empty result' do
      expect(response.result).to eq({})
    end
  end

  describe 'a result that is not an object' do
    let(:body) { { 'result' => 'oops' } }

    it 'does not raise' do
      expect { response.code }.not_to raise_error
    end

    it 'has an empty result' do
      expect(response.result).to eq({})
    end
  end

  describe 'a JSON body that is not an object' do
    let(:body) { '[1, 2, 3]' }

    it 'does not raise' do
      expect { response.code }.not_to raise_error
    end

    it 'has an empty result' do
      expect(response.result).to eq({})
    end
  end
end

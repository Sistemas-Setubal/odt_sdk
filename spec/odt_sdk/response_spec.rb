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

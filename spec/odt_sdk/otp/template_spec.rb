# frozen_string_literal: true

require 'odt_sdk'

RSpec.describe OdtSdk::Otp::Template do
  describe 'the default' do
    subject(:template) { described_class.new }

    it 'renders the code into the copy' do
      expect(template.render('0473')).to eq('Tu codigo de verificacion es 0473')
    end

    it 'carries no accents, which the default encoding would replace' do
      expect(OdtSdk::Encodings).to be_supports(template.render('0473'), OdtSdk::Encodings::REPLACING)
    end

    it 'fits a single SMS' do
      expect(template.render('0473').length).to be <= 160
    end

    it 'is exposed as a constant' do
      expect(described_class::DEFAULT).to include(described_class::PLACEHOLDER)
    end
  end

  describe 'a custom template' do
    it 'renders the code where the placeholder sits' do
      template = described_class.new '%{code} es tu codigo, no lo compartas'

      expect(template.render('0473')).to eq('0473 es tu codigo, no lo compartas')
    end

    it 'keeps the text it was given' do
      expect(described_class.new('Codigo: %{code}').text).to eq('Codigo: %{code}')
    end

    it 'renders every occurrence of the placeholder' do
      template = described_class.new '%{code} - repito, %{code}'

      expect(template.render('0473')).to eq('0473 - repito, 0473')
    end

    it 'leaves a stray percent sign alone' do
      template = described_class.new '50% de descuento con %{code}'

      expect(template.render('0473')).to eq('50% de descuento con 0473')
    end

    it 'leaves an unknown placeholder alone' do
      template = described_class.new 'Hola %{name}, tu codigo es %{code}'

      expect(template.render('0473')).to eq('Hola %{name}, tu codigo es 0473')
    end

    it 'stringifies a numeric code' do
      expect(described_class.new('Codigo: %{code}').render(1234)).to eq('Codigo: 1234')
    end

    it 'keeps a padded code padded' do
      expect(described_class.new('Codigo: %{code}').render('0007')).to eq('Codigo: 0007')
    end
  end

  describe 'accents in the copy' do
    it 'is refused under the default encoding' do
      expect { described_class.new 'Tu código de verificacion es %{code}' }
        .to raise_error(ArgumentError, /without accents/)
    end

    it 'points at UCS-2 as the way out' do
      expect { described_class.new 'Tu código es %{code}' }
        .to raise_error(ArgumentError, /UCS2/)
    end

    it 'is allowed when the template is built for UCS-2' do
      template = described_class.new 'Tu código es %{code}', encoding: OdtSdk::Encodings::UCS2

      expect(template.render('0473')).to eq('Tu código es 0473')
    end

    it 'remembers the encoding it was built for' do
      template = described_class.new 'Tu código es %{code}', encoding: OdtSdk::Encodings::UCS2

      expect(template.encoding).to eq(OdtSdk::Encodings::UCS2)
    end

    it 'defaults to the encoding ODT defaults to' do
      expect(described_class.new.encoding).to eq(OdtSdk::Encodings::REPLACING)
    end

    it 'fails when the template is built, not when the first code is sent' do
      expect { described_class.new 'Tu código es %{code}' }.to raise_error(ArgumentError)
    end
  end

  describe 'a template without the placeholder' do
    it 'is refused' do
      expect { described_class.new('Tu codigo de verificacion') }
        .to raise_error(ArgumentError, /placeholder/)
    end

    it 'says why it matters' do
      expect { described_class.new('Tu codigo de verificacion') }
        .to raise_error(ArgumentError, /never reaches the user/)
    end

    it 'refuses an empty template' do
      expect { described_class.new('') }.to raise_error(ArgumentError)
    end

    it 'refuses a nil template' do
      expect { described_class.new(nil) }.to raise_error(ArgumentError)
    end
  end
end

require 'spec_helper'

RSpec.describe Identity::Hostdata::Settings do
  let(:rails_env) { 'test' }
  let(:configuration) do
    {
      'test_key' => 'value',
      'production' => {
        'test_key' => 'overridden value',
      },
    }
  end
  let(:write_to_env) { false }

  before do
    stub_const('ENV', {})
  end

  subject(:settings) do
    Identity::Hostdata::Settings.new(
      configuration: configuration,
      rails_env: rails_env,
      write_to_env: write_to_env,
    )
  end

  describe '#initialize' do
    it 'warns and uses ENV when key is set in ENV and file config' do
      ENV['test_key'] = 'aaa'
      expect do
        expect(settings.test_key).to eq('aaa')
      end.to output(
        /test_key is being loaded from ENV/,
      ).to_stderr
    end

    context 'when a config value is not a string' do
      let(:configuration) do
        {
          'test_key' => 1,
        }
      end

      it 'warns if config value is not a string' do
        expect do
          settings
        end.to output(
          /test_key value must be String/,
        ).to_stderr
      end
    end

    context 'when a config key is not a string' do
      let(:configuration) do
        {
          1 => 'test',
        }
      end

      it 'warns if config value is not a string' do
        expect do
          settings
        end.to output(
          /key 1 must be String/,
        ).to_stderr
      end
    end

    context 'in a specific environment' do
      let(:rails_env) { 'production' }

      it 'overrides from specified environment key' do
        expect(settings.test_key).to eq('overridden value')
      end
    end

    context 'when write_to_env is true' do
      let(:write_to_env) { true }

      it 'sets ENV' do
        expect { settings }.to(change { ENV['test_key'] }.to('value'))
      end
    end

    context 'when write_to_env is false' do
      let(:write_to_env) { false }

      it 'sets ENV' do
        expect { settings }.to_not(change { ENV['test_key'] })
      end
    end
  end

  describe '#method_missing' do
    it 'reads from configuration' do
      expect(settings.test_key).to eq(configuration['test_key'])
    end
  end

  describe '#require_keys' do
    it 'does not raise an error if required keys are set' do
      expect(settings.require_keys(['test_key'])).to eq true
    end

    it 'raises an error if required key is not set' do
      expect { settings.require_keys(['unset_key']) }.to raise_error(
        RuntimeError,
        'unset_key is missing',
      )
    end
  end
end

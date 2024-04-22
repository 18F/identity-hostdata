require 'spec_helper'

RSpec.describe Identity::Hostdata::ConfigBuilder do
  subject(:config_builder) { Identity::Hostdata::ConfigBuilder.new }

  describe '::CONVERTERS' do
    describe 'comma_separated_string_list' do
      it 'respects double-quotes for embedded commas' do
        config = config_builder.build!({ csv_value: 'one,two,"three,four"' }) do |builder|
          builder.add(:csv_value, type: :comma_separated_string_list)
        end

        expect(config.csv_value).to eq(['one', 'two', 'three,four'])
      end

      it 'parses empty value as empty array' do
        config = config_builder.build!({ csv_value: '' }) do |builder|
          builder.add(:csv_value, type: :comma_separated_string_list)
        end

        expect(config.csv_value).to eq([])
      end
    end
  end

  before do
    stub_const('ENV', { 'SOME_ENV_VAR' => 'eee' })
  end

  let(:values) do
    {
      string_key: 'aaa',
      boolean_key: true,
      int_key: 111,
      commas_key: 'a,b,c',
      json_array: '["d","e","f"]',
      string_env_key: ['env', 'SOME_ENV_VAR'],
      never_used_key: 'never'
    }
  end

  subject(:build!) do
    config_builder.build!(values) do |builder|
      builder.add(:string_key, type: :string)
      builder.add(:boolean_key, type: :boolean)
      builder.add(:int_key, type: :integer)
      builder.add(:commas_key, type: :comma_separated_string_list)
      builder.add(:json_array, type: :json)
      builder.add(:string_env_key)
    end
  end

  describe '#build!' do
    it 'returns a struct with the values parsed correctly' do
      result = build!

      expect(result.string_key).to eq('aaa')
      expect(result.boolean_key).to eq(true)
      expect(result.int_key).to eq(111)
      expect(result.commas_key).to eq(%w[a b c ])
      expect(result.json_array).to eq(%w[d e f])
      expect(result.string_env_key).to eq('eee')
    end
  end

  describe '#key_types' do
    it 'tracks key types' do
      build!

      expect(config_builder.key_types).to eq(
        string_key: :string,
        boolean_key: :boolean,
        int_key: :integer,
        commas_key: :comma_separated_string_list,
        json_array: :json,
        string_env_key: :string,
      )
    end
  end

  describe '#unused_keys' do
    it 'tracks unused keys' do
      build!

      expect(config_builder.unused_keys).to eq([:never_used_key])
    end
  end
end

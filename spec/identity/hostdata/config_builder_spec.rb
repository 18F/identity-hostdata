require 'spec_helper'

RSpec.describe Identity::Hostdata::ConfigBuilder do
  subject(:config_builder) do
    Identity::Hostdata::ConfigBuilder.new
  end

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
end

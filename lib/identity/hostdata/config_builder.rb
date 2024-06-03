require 'csv'
require 'json'
require 'redacted_struct'
require 'aws-sdk-ssm'

module Identity
  module Hostdata
    # Helps build configurations, has a method +#add+ for defining values and their types
    # Retains type information on the builder itself (+#key_types+) as well as +#unused_keys+
    class ConfigBuilder
      CONVERTERS = {
        # Allows loading a string configuration from a system environment variable
        # ex: To read DATABASE_HOST from system environment for the database_host key
        # database_host: ['env', 'DATABASE_HOST']
        # To use a string value directly, you can specify a string explicitly:
        # database_host: 'localhost'
        string: proc do |value|
          if value.is_a?(Array) && value.length == 2 && value.first == 'env'
            ENV.fetch(value[1])
          elsif value.is_a?(String)
            value
          else
            raise 'invalid system environment configuration value'
          end
        end,
        symbol: proc { |value| value.to_sym },
        comma_separated_string_list: proc do |value|
          CSV.parse_line(value).to_a
        end,
        integer: proc do |value|
          Integer(value)
        end,
        float: proc do |value|
          Float(value)
        end,
        json: proc do |value, options: {}|
          JSON.parse(value, symbolize_names: options[:symbolize_names])
        end,
        boolean: proc do |value|
          case value
          when 'true', true
            true
          when 'false', false
            false
          else
            raise 'invalid boolean value'
          end
        end,
        date: proc { |value| Date.parse(value) if value },
        timestamp: proc do |value|
          # When the store is built `Time.zone` is not set resulting in a NoMethodError
          # if Time.zone.parse is called
          #
          # rubocop:disable Rails/TimeZone
          Time.parse(value)
          # rubocop:enable Rails/TimeZone
        end,
      }.freeze

      attr_reader :key_types, :unused_keys

      def initialize
        @written_env = {}
        @key_types = {}
      end

      def add(key, type: :string, allow_nil: false, enum: nil, options: {})
        value = @read_env[key]

        key_types[key] = type

        converted_value = convert!(
          key: key,
          value: value,
          type: type,
          allow_nil: allow_nil,
          enum: enum,
          options: options,
        )

        @written_env[key] = converted_value.freeze
      end

      def add_ssm(prop_name, ssm_name, type: :string, allow_nil: false, enum: nil, options: {})
        raw_value = load_ssm_value(ssm_name)

        key_types[prop_name] = type

        converted_value = if block_given?
          yield raw_value
        else
          convert!(
            key: prop_name,
            value: raw_value,
            type: type,
            allow_nil: allow_nil,
            enum: enum,
            options: options,
          )
        end

        @written_env[prop_name] = converted_value.freeze
      end

      # @api private
      def convert!(key:, value:, type:, allow_nil:, enum:, options:)
        converted_value = CONVERTERS.fetch(type).call(value, options: options) if !value.nil?
        raise "#{key} is required but is not present" if converted_value.nil? && !allow_nil
        if enum && !(enum.include?(converted_value) || (converted_value.nil? && allow_nil))
          raise "unexpected #{key}: #{value}, expected one of #{enum}"
        end

        converted_value
      end

      # @param [Hash] values the configuration values to read from to populate the config
      # @yieldparam [ConfigBuilder] builder for defining configuration values and types
      # @return [RedactedStruct]
      # @example
      #   struct = config_builder.build!(values) do |builder|
      #              builder.add(:my_key, type: :string)
      #            end
      def build!(values)
        @read_env = values

        yield self

        key_types.freeze
        @unused_keys = (@read_env.keys - @written_env.keys).freeze
        @written_env.freeze

        # Clear out @read_env to minimize the chance sensitive values get logged
        @read_env = nil

        RedactedStruct.new(*@written_env.keys, keyword_init: true).
          new(**@written_env)
      end

      def load_ssm_value(name)
        ssm_client.get_parameter(
          name: name,
          with_decryption: true,
        ).parameter.value.chomp
      end

      def ssm_client
        @ssm_client ||= Aws::SSM::Client.new(
          http_idle_timeout: 3,
          http_open_timeout: 3,
          http_read_timeout: 3,
        )
      end
    end
  end
end

require 'csv'
require 'json'
require 'redacted_struct'
require 'aws-sdk-secretsmanager'

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

      def add(
        key,
        secrets_manager_name: nil,
        type: :string,
        allow_nil: false,
        enum: nil,
        options: {}
      )
        value = if secrets_manager_name
          secrets_client.get_secret_value(secret_id: secrets_manager_name).secret_string
        else
          @read_env[key]
        end

        key_types[key] = type

        converted_value = if block_given?
          yield value
        else
          CONVERTERS.fetch(type).call(value, options: options) if !value.nil?
        end
        raise "#{key} is required but is not present" if converted_value.nil? && !allow_nil
        if enum && !(enum.include?(converted_value) || (converted_value.nil? && allow_nil))
          raise "unexpected #{key}: #{value}, expected one of #{enum}"
        end

        @written_env[key] = converted_value.freeze
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

      def secrets_client
        @secrets_client ||= Aws::SecretsManager::Client.new(
          http_idle_timeout: 5,
          http_open_timeout: 5,
          http_read_timeout: 5,
          instance_profile_credentials_retries: 3,
        )
      end
    end
  end
end

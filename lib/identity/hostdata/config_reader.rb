require 'logger'
require 'fileutils'
require 'yaml'

require "active_support"
require "active_support/core_ext/hash/deep_merge"
require "active_support/core_ext/hash/except"

module Identity
  module Hostdata
    class ConfigReader
      attr_reader :app_root, :logger

      # @param [Pathname] app_root
      def initialize(
        app_root:,
        s3_client: nil,
        logger: Logger.new(STDOUT)
      )
        @app_root = app_root
        @s3_client = s3_client
        @logger = logger
      end

      def read_configuration(rails_env, write_copy_to: nil)
        if write_copy_to && !File.exists?(write_copy_to)
          FileUtils.mkdir_p(File.dirname(write_copy_to))
          File.write(write_copy_to, base_configuration.to_yaml)
          FileUtils.chmod(0o640, write_copy_to)
        end

        base_configuration.except('development', 'production', 'test').merge(
          base_configuration[rails_env],
        ).transform_keys(&:to_sym)
      end

      private

      def base_configuration
        @base_configuration ||= default_configuration.deep_merge(
          app_override_configuration,
        ).deep_merge(
          role_override_configuration,
        )
      end

      def default_configuration
        YAML.safe_load(File.read(File.join(app_root, 'config', 'application.yml.default')))
      end

      def app_override_configuration
        local_config_filepath = File.join(app_root, 'config', 'application.yml')
        raw_configs = if Identity::Hostdata.in_datacenter?
                        app_secrets_s3.read_file(app_configuration_s3_path)
                      elsif File.exists?(local_config_filepath)
                        File.read(local_config_filepath)
                      end
        YAML.safe_load(raw_configs || '{}') || {}
      end

      def role_override_configuration
        return {} if role_configuration_filename.nil?
        local_config_filepath = File.join(app_root, 'config', role_configuration_filename)

        raw_configs = if Identity::Hostdata.in_datacenter?
                        app_secrets_s3.read_file(role_configuration_s3_path)
                      elsif File.exists?(local_config_filepath)
                        File.read(local_config_filepath)
                      end

        YAML.safe_load(raw_configs || '{}') || {}
      end

      def app_secrets_s3
        @app_secrets_s3 ||= Identity::Hostdata.app_secrets_s3(logger: @logger, s3_client: @s3_client)
      end

      def app_configuration_s3_path
        "/%<env>s/#{app_configuration_path_component}/v1/application.yml"
      end

      def role_configuration_s3_path
        return if role_configuration_filename.nil?
        "/%<env>s/#{app_configuration_path_component}/v1/#{role_configuration_filename}"
      end

      def app_configuration_path_component
        return 'idp' if Identity::Hostdata.instance_role == 'worker'
        return 'dashboard' if Identity::Hostdata.instance_role == 'app'
        Identity::Hostdata.instance_role
      end

      def role_configuration_filename
        case Identity::Hostdata.instance_role
        when 'idp'
          'web.yml'
        when 'worker'
          'worker.yml'
        end
      end
    end
  end
end

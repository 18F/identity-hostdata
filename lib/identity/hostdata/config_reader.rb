require 'logger'
require 'fileutils'
require 'yaml'

require "active_support"
require "active_support/core_ext/hash/deep_merge"
require "active_support/core_ext/hash/except"

module Identity
  module Hostdata
    Configuration = Struct.new(:hash, :version, :updated_at, keyword_init: true)
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
        if write_copy_to && !File.exist?(write_copy_to)
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
        @base_configuration ||= default_configuration.hash.deep_merge(
          app_override_configuration.hash,
        )
      end

      def default_configuration
        return @default_configuration if defined?(@default_configuration)
        path = File.join(Rails.root, 'config', 'application.yml.default')
        @default_configuration = build_configuration_from_file_path(path)
      end

      def app_override_configuration
        return @app_override_configuration if defined?(@app_override_configuration)
        local_config_filepath = File.join(app_root, 'config', 'application.yml')

        @app_override_configuration =
          if Identity::Hostdata.in_datacenter? && !ENV['LOGIN_SKIP_REMOTE_CONFIG']
            s3_object = app_secrets_s3.get_object(app_configuration_s3_path)
            return Configuration.new(hash: {}) if s3_object.nil?

            Configuration.new(
              hash: YAML.safe_load(s3_object.body.read),
              version: s3_object.version_id,
              updated_at: s3_object.last_modified,
            )
          elsif File.exist?(local_config_filepath)
            build_configuration_from_file_path(local_config_filepath)
          else
            Configuration.new(
              hash: {},
              version: nil,
              updated_at: nil,
            )
          end

        @app_override_configuration
      end

      def app_secrets_s3
        @app_secrets_s3 ||= Identity::Hostdata.app_secrets_s3(logger: @logger, s3_client: @s3_client)
      end

      def app_configuration_s3_path
        "/%<env>s/#{app_configuration_path_component}/v1/application.yml"
      end

      def app_configuration_path_component
        return 'idp' if Identity::Hostdata.instance_role == 'worker'
        return 'idp' if Identity::Hostdata.instance_role == 'migration'
        return 'dashboard' if Identity::Hostdata.instance_role == 'app'
        Identity::Hostdata.instance_role
      end

      def build_configuration_from_file_path(path)
        file_stat = File.stat(path)
        configuration = YAML.safe_load(File.read(path))
        @default_configuration = Configuration.new(
          hash: configuration,
          version: nil,
          updated_at: file_stat.mtime,
        )
      end
    end
  end
end

require 'logger'
require 'fileutils'
require 'yaml'

require "active_support"
require "active_support/core_ext/hash/deep_merge"
require "active_support/core_ext/hash/except"

module Identity
  module Hostdata
    class ConfigReader
      ConfigVersion = RedactedStruct.new(
        :name,
        :content,
        :version,
        :last_updated,
        keyword_init: true,
      )
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

      def configuration_version
        {
          default: {
            version: default_configuration[:version],
            last_updated: default_configuration[:last_updated],
          },
          app_override: {
            version: app_override_configuration[:version],
            last_updated: app_override_configuration[:last_updated],
          }
        }
      end

      private

      def base_configuration
        @base_configuration ||= default_configuration.content.deep_merge(
          app_override_configuration.content,
        )
      end

      def default_configuration
        return @default_configuration if defined?(@default_configuration)
        path = File.join(app_root, 'config', 'application.yml.default')
        @default_configuration = config_version_from_local_file(path: path)
      end

      def app_override_configuration
        return @app_override_configuration if defined?(@app_override_configuration)

        local_config_filepath = File.join(app_root, 'config', 'application.yml')

        @app_override_configuration = if Identity::Hostdata.in_datacenter? && !ENV['LOGIN_SKIP_REMOTE_CONFIG']
          s3_object = app_secrets_s3.request_object(app_configuration_s3_path)
          content = YAML.safe_load(s3_object.body.read)
          ConfigVersion.new(content: content, version: s3_object.version_id, last_updated: s3_object.last_modified)
        elsif File.exist?(local_config_filepath)
          config_version_from_local_file(path: local_config_filepath)
        else
          ConfigVersion.new(content: {}, version: nil, last_updated: nil)
        end

        @app_override_configuration
      end

      def app_secrets_s3
        @app_secrets_s3 ||= Identity::Hostdata.app_secrets_s3(logger: @logger, s3_client: @s3_client)
      end

      def config_version_from_local_file(path:)
        stat = File.stat(path)
        content = YAML.safe_load_file(path) || {}
        ConfigVersion.new(content: content, version: nil, last_updated: stat.mtime)
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
    end
  end
end

require "identity/hostdata/ec2"
require "identity/hostdata/s3"
require "identity/hostdata/settings"
require "identity/hostdata/version"
require "json"

module Identity
  module Hostdata
    class MissingConfigError < StandardError; end

    CONFIG_DIR = '/etc/login.gov'
    DOMAIN_PATH = File.join(CONFIG_DIR, 'info/domain')
    ENV_PATH = File.join(CONFIG_DIR, 'info/env')
    INSTANCE_ROLE_PATH = File.join(CONFIG_DIR, 'info/role')

    # @param [Hash] configuration
    # @param [String] rails_env from +Rails.env+
    # Sets up Identity::Hostdata.settings, should be called before that is accessed
    def self.setup_settings!(configuration:, rails_env:)
      @settings = Settings.new(configuration: configuration, rails_env: rails_env)
    end

    # @return [String]
    def self.domain
      @domain ||= begin
        File.read(DOMAIN_PATH).chomp
      rescue Errno::ENOENT => err
        raise MissingConfigError, err.message if in_datacenter?
      end
    end

    # @return [String]
    def self.env
      @env ||= begin
        File.read(ENV_PATH).chomp
      rescue Errno::ENOENT => err
        raise MissingConfigError, err.message if in_datacenter?
      end
    end

    # @return [Hash] parses the environment's config JSON
    def self.config
      @config ||= begin
        config_path = File.join(
          CONFIG_DIR,
          'repos/identity-devops/kitchen/environments',
          "#{env}.json"
        )

        JSON.parse(File.read(config_path), symbolize_names: true)
      rescue Errno::ENOENT => err
        raise MissingConfigError, err.message if in_datacenter?
        {}
      end
    end

    # @return [String]
    def self.instance_role
      @instance_role ||= begin
        File.read(INSTANCE_ROLE_PATH).chomp
      rescue Errno::ENOENT => err
        raise MissingConfigError, err.message if in_datacenter?
      end
    end

    # @return [Boolean]
    def self.in_datacenter?
      return @in_datacenter if defined?(@in_datacenter)
      @in_datacenter = File.directory?(CONFIG_DIR)
    end

    # @yield Executes a block if in_datacenter?
    # @yieldparam hostdata
    def self.in_datacenter
      raise LocalJumpError, 'in_datacenter must be called with a block' unless block_given?
      yield self if in_datacenter?
    end

    # @return [S3]
    def self.s3(logger: default_logger, s3_client: nil)
      ec2 = Identity::Hostdata::EC2.load

      Identity::Hostdata::S3.new(
        env: env,
        region: ec2.region,
        logger: logger,
        s3_client: s3_client,
        bucket: "login-gov.app-secrets.#{ec2.account_id}-#{ec2.region}"
      )
    end

    # @return [Logger]
    def self.logger
      @logger ||= Logger.new(STDOUT)
    end

    class << self
      alias_method :default_logger, :logger

      attr_writer :logger

      attr_reader :settings
    end

    # @api private
    # Used to clear memoized values (intended for specs)
    def self.reset!
      instance_variables.each do |variable|
        remove_instance_variable(variable)
      end
    end
  end
end

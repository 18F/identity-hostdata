require "json"
require "login_gov/hostdata/ec2"
require "login_gov/hostdata/log_formatter"
require "login_gov/hostdata/s3"
require "login_gov/hostdata/version"
require "login_gov/hostdata/railtie" if defined?(Rails::Railtie)

module LoginGov
  module Hostdata
    class MissingConfigError < StandardError; end

    CONFIG_DIR = '/etc/login.gov'
    DOMAIN_PATH = File.join(CONFIG_DIR, 'info/domain')
    ENV_PATH = File.join(CONFIG_DIR, 'info/env')
    INSTANCE_ROLE_PATH = File.join(CONFIG_DIR, 'info/role')

    def self.domain
      @domain ||= begin
        File.read(DOMAIN_PATH).chomp
      rescue Errno::ENOENT => err
        raise MissingConfigError, err.message if in_datacenter?
      end
    end

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

    def self.instance_role
      @instance_role ||= begin
        File.read(INSTANCE_ROLE_PATH).chomp
      rescue Errno::ENOENT => err
        raise MissingConfigError, err.message if in_datacenter?
      end
    end

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
      ec2 = LoginGov::Hostdata::EC2.load

      LoginGov::Hostdata::S3.new(
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

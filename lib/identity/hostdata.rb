require "identity/hostdata/ec2"
require "identity/hostdata/s3"
require "identity/hostdata/version"
require "json"

module Identity
  module Hostdata
    class MissingConfigError < StandardError; end

    CONFIG_DIR = '/etc/login.gov'
    DOMAIN_PATH = File.join(CONFIG_DIR, 'info/domain')
    ENV_PATH = File.join(CONFIG_DIR, 'info/env')
    INSTANCE_ROLE_PATH = File.join(CONFIG_DIR, 'info/role')

    # @return [String]
    def self.domain
      @domain ||= begin
        ENV['LOGIN_DOMAIN'] || File.read(File.join(root.to_s, DOMAIN_PATH)).chomp
      rescue Errno::ENOENT => err
        raise MissingConfigError, err.message if in_datacenter?
      end
    end

    # @return [String]
    def self.env
      @env ||= begin
        ENV['LOGIN_ENV'] || File.read(File.join(root.to_s, ENV_PATH)).chomp
      rescue Errno::ENOENT => err
        raise MissingConfigError, err.message if in_datacenter?
      end
    end

    # @return [Hash] parses the environment's config JSON
    def self.config
      @config ||= begin
        config_path = File.join(
          root.to_s,
          CONFIG_DIR,
          'repos/identity-devops/kitchen/environments',
          "#{env}.json"
        )
        config_contents = ENV['LOGIN_HOST_CONFIG'] || File.read(config_path)

        JSON.parse(config_contents, symbolize_names: true)
      rescue Errno::ENOENT => err
        raise MissingConfigError, err.message if in_datacenter?
        {}
      end
    end

    # @return [String]
    def self.instance_role
      @instance_role ||= begin
        ENV['LOGIN_HOST_ROLE'] || File.read(File.join(root.to_s, INSTANCE_ROLE_PATH)).chomp
      rescue Errno::ENOENT => err
        raise MissingConfigError, err.message if in_datacenter?
      end
    end

    # @return [Boolean]
    def self.in_datacenter?
      return @in_datacenter if defined?(@in_datacenter)
      @in_datacenter = ENV['LOGIN_DATACENTER'] == 'true' ||
                         File.directory?(File.join(root.to_s, CONFIG_DIR))
    end

    # @yield Executes a block if in_datacenter?
    # @yieldparam hostdata
    def self.in_datacenter
      raise LocalJumpError, 'in_datacenter must be called with a block' unless block_given?
      yield self if in_datacenter?
    end

    # @return [String]
    def self.aws_region
      @aws_region ||= ENV['LOGIN_AWS_REGION'] ||  Identity::Hostdata::EC2.load.region
    end

    # @return [String]
    def self.aws_account_id
      @aws_account_id ||= ENV['LOGIN_AWS_ACCOUNT_ID'] || Identity::Hostdata::EC2.load.account_id
    end

    # @return [S3] An S3 object configured to use the app-secrets bucket
    def self.app_secrets_s3(logger: default_logger, s3_client: nil)
      bucket = "login-gov.app-secrets.#{aws_account_id}-#{aws_region}"

      Identity::Hostdata::S3.new(
        env: env,
        region: aws_region,
        logger: logger,
        s3_client: s3_client,
        bucket: bucket
      )
    end

    # @return [S3] An S3 object configured to use the secrets bucket
    def self.secrets_s3(logger: default_logger, s3_client: nil)
      bucket = "login-gov.secrets.#{aws_account_id}-#{aws_region}"

      Identity::Hostdata::S3.new(
        env: env,
        region: aws_region,
        logger: logger,
        s3_client: s3_client,
        bucket: bucket
      )
    end

    # @return [Logger]
    def self.logger
      @logger ||= Logger.new(STDOUT)
    end

    class << self
      alias_method :default_logger, :logger

      attr_accessor :root

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

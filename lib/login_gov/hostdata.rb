require "login_gov/hostdata/ec2"
require "login_gov/hostdata/s3"
require "login_gov/hostdata/version"

module LoginGov
  module Hostdata
    class MissingConfigError < StandardError; end

    CONFIG_DIR = '/etc/login.gov'
    DOMAIN_PATH = File.join(CONFIG_DIR, 'info/domain')
    ENV_PATH = File.join(CONFIG_DIR, 'info/env')

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

    def self.in_datacenter?
      File.directory?(CONFIG_DIR)
    end

    # @yield Executes a block if in_datacenter?
    # @yieldparam hostdata
    def self.in_datacenter
      raise LocalJumpError, 'in_datacenter must be called with a block' unless block_given?
      yield self if in_datacenter?
    end

    # @return [S3]
    def self.s3(logger: default_logger)
      ec2 = LoginGov::Hostdata::EC2.load

      LoginGov::Hostdata::S3.new(
        env: env,
        region: ec2.region,
        logger: logger,
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

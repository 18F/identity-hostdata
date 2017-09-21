require "identity/hostdata/version"

module Identity
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

    # @api private
    # Used to clear memoized values (intended for specs)
    def self.reset!
      instance_variables.each do |variable|
        remove_instance_variable(variable)
      end
    end
  end
end

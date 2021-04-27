require 'net/http'

module Identity
  module Hostdata
    # Class to wrap accessing the EC2 metadata service
    class EC2
      # Standard initializer
      #
      # @return [EC2]
      def self.load
        response = http.get('/2016-09-02/dynamic/instance-identity/document', 'X-aws-ec2-metadata-token' => v2_token)
        new(JSON.parse(response.body))
      end

      # @api private
      def self.http
        http = Net::HTTP.new('169.254.169.254', 80)
        http.read_timeout = 1
        http.continue_timeout = 1
        http.open_timeout = 1
        http
      end

      # get token
      def self.v2_token
        http.put('/latest/api/token', nil, 'X-aws-ec2-metadata-token-ttl-seconds' => '60').body.chomp
      end 

      attr_reader :document

      # @param [Hash] document An instance identity document parsed from JSON
      #   returned by the EC2 metadata service at
      #   http://169.254.169.254/2016-09-02/dynamic/instance-identity/document
      def initialize(document)
        @document = document
      end

      # @return [String] Current EC2 region
      def region
        document.fetch('region')
      end

      # @return [String] Current AWS account ID
      def account_id
        document.fetch('accountId')
      end
    end
  end
end

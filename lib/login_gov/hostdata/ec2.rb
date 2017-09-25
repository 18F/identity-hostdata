require 'net/http'

module LoginGov
  module Hostdata
    class EC2
      # @return [EC2]
      def self.load
        response = http.get('/2016-09-02/dynamic/instance-identity/document')
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

      attr_reader :document

      def initialize(document)
        @document = document
      end

      def region
        document['region']
      end

      def account_id
        document['accountId']
      end
    end
  end
end

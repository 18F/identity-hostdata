module LoginGov
  module Hostdata
    # In-memory imitation of Aws::S3::Client for use in tests
    # Not required by default, use `require 'login_gov/hostdata/fake_s3_client'`
    class FakeS3Client
      def get_object(bucket:, key:, response_target:)
        File.open(response_target, 'wb') do |file|
          file.write(objects[full_key(bucket, key)])
        end
      end

      def put_object(bucket:, key:, body:)
        objects[full_key(bucket, key)] = body
      end

      # @api private
      def objects
        @objects ||= {}
      end

      # @api private
      def full_key(bucket, key)
        File.join(bucket, key)
      end
    end
  end
end

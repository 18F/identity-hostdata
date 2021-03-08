module Identity
  module Hostdata
    # In-memory imitation of Aws::S3::Client for use in tests
    # Not required by default, use `require 'identity/hostdata/fake_s3_client'`
    class FakeS3Client
      GetObjectResponse = Struct.new(:body)

      def get_object(bucket:, key:, response_target: nil)
        object_contents = objects[full_key(bucket, key)]
        raise Aws::S3::Errors::NoSuchKey.new('a', 'b') if object_contents.nil?

        if response_target
          File.open(response_target, 'wb') do |file|
            file.write(object_contents)
          end
        else
          GetObjectResponse.new(StringIO.new(object_contents))
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

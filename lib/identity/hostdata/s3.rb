require 'aws-sdk-s3'
require 'fileutils'
require 'json'
require 'logger'

module Identity
  module Hostdata
    class S3
      attr_reader :bucket, :env, :region, :logger

      def initialize(bucket:, env:, region:, s3_client: nil, logger: nil)
        @bucket = bucket
        @env = env
        @region = region
        @logger = logger
        @s3_client = s3_client
      end

      def download_file(s3_path, local_path)
        key = build_key(s3_path)

        logger && logger.info("#{self.class}: downloading s3://#{bucket}/#{key} to #{local_path}")

        s3_response = get_s3_object(key)
        stream_s3_object_to_file(s3_response, local_path)
      end

      def read_file(s3_path)
        key = build_key(s3_path)

        logger && logger.info("#{self.class}: reading s3://#{bucket}/#{key}")

        get_s3_object(key).body.read
      rescue Aws::S3::Errors::NoSuchKey
        nil
      end

      private

      def build_key(s3_path)
        format(s3_path, env: env).sub(%r|\A/|, '')
      end

      def get_s3_object(key)
        s3_client.get_object(
          bucket: bucket,
          key: key,
        )
      end

      def stream_s3_object_to_file(s3_object_response, file_path)
        FileUtils.mkdir_p(File.dirname(file_path))

        File.open(file_path, 'wb') do |file|
          while bytes = s3_object_response.body.read(512)
            file.write(bytes)
          end
        end
      end

      def s3_client
        @s3_client ||= Aws::S3::Client.new(
          region: region,
          http_open_timeout: 5,
          http_read_timeout: 5
        )
      end
    end
  end
end

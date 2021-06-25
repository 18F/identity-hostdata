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

      def download_file(s3_path:, local_path:)
        key = build_key(s3_path)

        logger && logger.info("#{self.class}: downloading s3://#{bucket}/#{key} to #{local_path}")

        FileUtils.mkdir_p(File.dirname(local_path))
        s3_response = make_s3_get_object_request(key: key, response_target: local_path)
      end

      def read_file(s3_path)
        key = build_key(s3_path)

        logger && logger.info("#{self.class}: reading s3://#{bucket}/#{key}")

        make_s3_get_object_request(key: key).body.read
      rescue Aws::S3::Errors::NoSuchKey
        nil
      end

      private

      def build_key(s3_path, response_target = nil)
        format(s3_path, env: env).sub(%r|\A/|, '')
      end

      def make_s3_get_object_request(key:, response_target: nil)
        s3_client.get_object(
          bucket: bucket,
          key: key,
          response_target: response_target,
        )
      end

      def s3_client
        @s3_client ||= Aws::S3::Client.new(
          region: region,
          http_open_timeout: 5,
          http_read_timeout: 5
          signature_version: 'v4',
          compute_checksums: false,
        )
      end
    end
  end
end

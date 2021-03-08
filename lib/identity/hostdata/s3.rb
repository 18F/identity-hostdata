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

      def download_config(s3_path, local_path)
        FileUtils.mkdir_p(File.dirname(local_path))

        key = format(s3_path, env: env).sub(%r|\A/|, '')

        logger && logger.info("#{self.class}: downloading s3://#{bucket}/#{key} to #{local_path}")

        s3_client.get_object(
          bucket: bucket,
          key: key,
          response_target: local_path
        )
      end

      def read_config(s3_path)
        key = format(s3_path, env: env).sub(%r|\A/|, '')

        logger && logger.info("#{self.class}: reading s3://#{bucket}/#{key}")

        s3_client.get_object(
          bucket: bucket,
          key: key,
        ).body.read
      rescue Aws::S3::Errors::NoSuchKey
        nil
      end

      private

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

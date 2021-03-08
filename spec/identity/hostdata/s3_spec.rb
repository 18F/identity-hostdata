require 'spec_helper'

RSpec.describe Identity::Hostdata::S3 do
  let(:fake_s3) { Identity::Hostdata::FakeS3Client.new }

  around(:each) do |ex|
    Identity::Hostdata.reset!

    @logger = Logger.new('/dev/null') # set up before FakeFS

    FakeFS.with_fresh do
      ex.run
    end
  end

  let(:bucket) { 'some-bucket-name' }
  let(:env) { 'staging' }
  let(:region) { 'us-west-2' }
  let(:logger) { @logger }
  subject(:s3) do
    Identity::Hostdata::S3.new(
      bucket: bucket,
      env: env,
      region: region,
      logger: logger,
      s3_client: fake_s3
    )
  end

  describe '#download_config' do
    let(:local_config_file) { '/srv/idp/current/config/config.yml' }

    subject(:download_config) do
      s3.download_config('/%{env}/v1/idp/some_config.yml', local_config_file)
    end

    let(:config_body) { 'test config data' }

    before do
      fake_s3.put_object(
        bucket: bucket,
        key: "/#{env}/v1/idp/some_config.yml",
        body: config_body
      )
    end

    it 'interpolates filenames, downloads from s3 and writes them to the local path' do
      download_config

      expect(File.read(local_config_file)).to eq(config_body)
    end

    it 'chops off leading slashes from s3 paths' do
      expect(fake_s3).to receive(:get_object).with(
        bucket: bucket,
        key: 'staging/v1/idp/some_config.yml',
        response_target: local_config_file
      )

      download_config
    end

    it 'logs which files its downloading' do
      expect(logger).to receive(:info).with(
        "Identity::Hostdata::S3: downloading s3://some-bucket-name/staging/v1/idp/some_config.yml to #{local_config_file}"
      )

      download_config
    end
  end

  describe '#read_config' do
    subject(:read_config) do
      s3.read_config('/%{env}/v1/idp/some_config.yml')
    end

    let(:config_body) { 'test config data' }

    before do
      fake_s3.put_object(
        bucket: bucket,
        key: "/#{env}/v1/idp/some_config.yml",
        body: config_body
      )
    end

    it 'interpolates filenames, downloads from s3 and returns the contents as a string' do
      expect(read_config).to eq(config_body)
    end

    it 'returns nil if the object does not exist in s3' do
      result = s3.read_config('/no/such/key.yml')
      expect(result).to eq(nil)
    end

    it 'chops off leading slashes from s3 paths' do
      expect(fake_s3).to receive(:get_object).with(
        bucket: bucket,
        key: 'staging/v1/idp/some_config.yml',
      ).and_call_original

      read_config
    end

    it 'logs which files its reading' do
      expect(logger).to receive(:info).with(
        "Identity::Hostdata::S3: reading s3://some-bucket-name/staging/v1/idp/some_config.yml"
      )

      read_config
    end
  end
end

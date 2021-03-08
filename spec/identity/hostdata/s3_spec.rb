require 'spec_helper'
require 'pry-byebug'

RSpec.describe Identity::Hostdata::S3 do
  around(:each) do |ex|
    Identity::Hostdata.reset!

    # set up before FakeFS
    @logger = Logger.new('/dev/null')
    @fake_s3 = Aws::S3::Client.new(stub_responses: true)

    FakeFS.with_fresh do
      ex.run
    end
  end

  let(:bucket) { 'some-bucket-name' }
  let(:env) { 'staging' }
  let(:region) { 'us-west-2' }
  let(:logger) { @logger }
  let(:fake_s3) { @fake_s3 }
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
      @fake_s3.stub_responses(
        :get_object,
        { body: config_body }
      )
    end

    it 'builds the key, downloads file from s3 and writes them to the local path' do
      expect(fake_s3).to receive(:get_object).with(
        bucket: bucket,
        key: "#{env}/v1/idp/some_config.yml"
      ).and_call_original

      download_config

      expect(File.read(local_config_file)).to eq(config_body)
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

    it 'builds the key, downloads the file from s3 and returns the contents as a string' do
      @fake_s3.stub_responses(:get_object, { body: config_body })

      expect(fake_s3).to receive(:get_object).with(
        bucket: bucket,
        key: "#{env}/v1/idp/some_config.yml"
      ).and_call_original

      expect(read_config).to eq(config_body)
    end

    it 'returns nil if the object does not exist in s3' do
      @fake_s3.stub_responses(:get_object, 'NoSuchKey')

      result = s3.read_config('/no/such/key.yml')
      expect(result).to eq(nil)
    end

    it 'logs which files it is reading' do
      @fake_s3.stub_responses(:get_object, { body: config_body })

      expect(logger).to receive(:info).with(
        "Identity::Hostdata::S3: reading s3://some-bucket-name/staging/v1/idp/some_config.yml"
      )

      read_config
    end
  end
end

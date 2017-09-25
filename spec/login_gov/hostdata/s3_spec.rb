require 'spec_helper'

RSpec.describe LoginGov::Hostdata::S3 do
  let(:fake_s3) { FakeS3.new }

  around(:each) do |ex|
    LoginGov::Hostdata.reset!

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
    LoginGov::Hostdata::S3.new(
      bucket: bucket,
      env: env,
      region: region,
      logger: logger,
      s3_client: fake_s3
    )
  end

  describe '#download_configs' do
    let(:local_config_file) { '/srv/idp/current/config/config.yml' }

    subject(:download_configs) do
      s3.download_configs(
        '/%{env}/v1/idp/some_config.yml' => local_config_file
      )
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
      download_configs

      expect(File.read(local_config_file)).to eq(config_body)
    end

    it 'chops off leading slashes from s3 paths' do
      expect(fake_s3).to receive(:get_object).with(
        bucket: bucket,
        key: 'staging/v1/idp/some_config.yml',
        response_target: local_config_file
      )

      download_configs
    end

    it 'logs which files its downloading' do
      expect(logger).to receive(:info).with(
        "LoginGov::Hostdata::S3: downloading s3://some-bucket-name/staging/v1/idp/some_config.yml to #{local_config_file}"
      )

      download_configs
    end
  end
end

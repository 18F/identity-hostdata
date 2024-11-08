require 'spec_helper'

RSpec.describe Identity::Hostdata::ConfigReader do
  DEFAULT_YAML = <<~HEREDOC
    base_config: 'test'
    overriden_env_config: 'override me' # Overriden below for development'
    overriden_base_config: 'override me' # Overriden in application.yml

    development:
      env_config: 'test'
      overriden_env_config: 'test'
  HEREDOC

  OVERRIDE_YAML = <<~HEREDOC
    development:
      overriden_base_config: 'test'
  HEREDOC

  let(:app_root) { @app_root }

  around(:each) do |ex|
    Dir.mktmpdir do |app_root|
      @app_root = app_root
      set_tmp_dir_fixtures(app_root)
      ex.run
    end
  end

  let(:logger) { Logger.new('/dev/null') }
  let(:s3_client) { nil }

  subject(:reader) { described_class.new(app_root: app_root, logger: logger, s3_client: s3_client) }

  context 'in the datacenter' do
    let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }
    let(:s3_contents) do
      {
        'int/idp/v1/application.yml' => OVERRIDE_YAML,
      }
    end
    let(:ec2_api_token) { SecureRandom.hex }

    before do
      allow(Identity::Hostdata).to receive(:in_datacenter?).and_return(true)
      allow(Identity::Hostdata).to receive(:instance_role).and_return('idp')
      allow(Identity::Hostdata).to receive(:env).and_return('int')

      stub_request(:put, 'http://169.254.169.254/latest/api/token').
          with(headers: { 'X-Aws-Ec2-Metadata-Token-Ttl-Seconds' => '60' }).
          to_return(body: ec2_api_token)
      stub_request(:get, 'http://169.254.169.254/2016-09-02/dynamic/instance-identity/document').
          with(headers: { 'X-aws-ec2-metadata-token' => ec2_api_token }).
          to_return(body: {
            'region' => 'us-west-1',
            'accountId' => '12345',
          }.to_json)

      s3_client.stub_responses(
        :get_object, proc do |context|
          key = context.params[:key]
          body = s3_contents[key]
          if body
            { last_modified: Time.now, version_id: '123', body: body }
          else
            raise Aws::S3::Errors::NoSuchKey.new(nil, nil)
          end
        end
      )
      allow(s3_client).to receive(:get_object).and_call_original
    end

    it 'merges the default and override yaml values' do
      configuration = reader.read_configuration('development')

      expect(s3_client).to have_received(:get_object).with(
        hash_including(key: 'int/idp/v1/application.yml'),
      )
      expect(configuration).to eq(
        base_config: 'test',
        env_config: 'test',
        overriden_env_config: 'test',
        overriden_base_config: 'test',
      )
    end

    context 'on idps' do
      before do
        allow(Identity::Hostdata).to receive(:instance_role).and_return('idp')
        expect(s3_client).to receive(:get_object).with(
          hash_including(key: 'int/idp/v1/application.yml')
        ).and_call_original
      end

      it 'resolves the s3 paths correctly' do
        s3_contents['int/idp/v1/application.yml'] = 'config1: hello'

        configuration = reader.read_configuration('development')

        expect(configuration[:config1]).to eq('hello')
      end


      it 'has version information' do
        expect(reader.configuration_version).to include(
          default: {
            version: an_instance_of(String),
            last_updated: an_instance_of(Time),
          },
          app_override: {
            version: '123',
            last_updated: an_instance_of(Time),
          }
        )
      end
    end

    context 'on workers' do
      it 'resolves the s3 paths correctly' do
        allow(Identity::Hostdata).to receive(:instance_role).and_return('worker')

        s3_contents['int/idp/v1/application.yml'] = 'config1: hello'

        expect(s3_client).to receive(:get_object).with(
          hash_including(key: 'int/idp/v1/application.yml')
        ).and_call_original
        configuration = reader.read_configuration('development')

        expect(configuration[:config1]).to eq('hello')
      end
    end

    context 'on migration instances' do
      it 'resolves the s3 paths correctly' do
        allow(Identity::Hostdata).to receive(:instance_role).and_return('migration')

        s3_contents['int/idp/v1/application.yml'] = 'config1: hello'

        expect(s3_client).to receive(:get_object).with(
          hash_including(key: 'int/idp/v1/application.yml')
        ).and_call_original

        configuration = reader.read_configuration('development')

        expect(configuration[:config1]).to eq('hello')
      end
    end

    context 'on pivcacs' do
      it 'resolves the s3 paths correctly' do
        allow(Identity::Hostdata).to receive(:instance_role).and_return('pivcac')

        s3_contents['int/pivcac/v1/application.yml'] = 'config1: hello'

        expect(s3_client).to receive(:get_object).with(
          hash_including(key: 'int/pivcac/v1/application.yml')
        ).and_call_original

        configuration = reader.read_configuration('development')

        expect(configuration[:config1]).to eq('hello')
      end
    end

    context 'on dashboards' do
      it 'resolves the s3 paths correctly' do
        allow(Identity::Hostdata).to receive(:instance_role).and_return('app')

        s3_contents['int/dashboard/v1/application.yml'] = 'config1: hello'

        expect(s3_client).to receive(:get_object).with(
          hash_including(key: 'int/dashboard/v1/application.yml')
        ).and_call_original

        configuration = reader.read_configuration('development')

        expect(configuration[:config1]).to eq('hello')
      end
    end
  end

  context 'during local dev' do
    it 'merges the default and override configurations' do
      configuration = reader.read_configuration('development')

      expect(configuration).to eq(
        base_config: 'test',
        env_config: 'test',
        overriden_env_config: 'test',
        overriden_base_config: 'test',
      )
    end

    it 'has version information' do
      expect(reader.configuration_version).to include(
        default: {
          version: an_instance_of(String),
          last_updated: an_instance_of(Time),
        },
        app_override: {
          version: an_instance_of(String),
          last_updated: an_instance_of(Time),
        }
      )
    end
  end

  def set_tmp_dir_fixtures(root)
    FileUtils.mkdir_p(File.join(root, 'config'))
    File.write(File.join(root, 'config', 'application.yml.default'), DEFAULT_YAML)
    File.write(File.join(root, 'config', 'application.yml'), OVERRIDE_YAML)
  end
end

require "spec_helper"

RSpec.describe Identity::Hostdata do
  it "has a version number" do
    expect(Identity::Hostdata::VERSION).not_to be nil
  end

  around(:each) do |ex|
    Identity::Hostdata.reset!

    Dir.mktmpdir do |root|
      @root = root
      Identity::Hostdata.root = root
      ex.run
    end
  end

  describe '.domain' do
    context 'when /etc/login.gov exists (in a datacenter environment)' do
      before { FileUtils.mkdir_p("#{@root}/etc/login.gov") }

      context 'when the info/domain file exists' do
        before do
          FileUtils.mkdir_p("#{@root}/etc/login.gov/info")
          File.open("#{@root}/etc/login.gov/info/domain", 'w') { |f| f.puts 'identitysandbox.gov' }
        end

        it 'reads the contents of the file' do
          expect(Identity::Hostdata.domain).to eq('identitysandbox.gov')
        end
      end

      context 'when the info/domain file does not exist' do
        it 'blows up' do
          expect { Identity::Hostdata.domain }.
            to raise_error(Identity::Hostdata::MissingConfigError)
        end
      end
    end

    context 'when the LOGIN_DOMAIN env var is set' do
      before do
        stub_const(
          'ENV',
          { 'LOGIN_DOMAIN' => 'identityenvbox.gov', 'LOGIN_DATACENTER' => 'true' },
        )
      end

      it 'reads the value of the env var' do
        expect(Identity::Hostdata.domain).to eq('identityenvbox.gov')
      end
    end

    context 'when /etc/login.gov does not exist (development environment)' do
      it 'is nil' do
        expect(Identity::Hostdata.domain).to eq(nil)
      end
    end
  end

  describe '.env' do
    context 'when /etc/login.gov exists (in a datacenter environment)' do
      before { FileUtils.mkdir_p("#{@root}/etc/login.gov") }

      context 'when the info/env file exists' do
        before do
          FileUtils.mkdir_p("#{@root}/etc/login.gov/info")
          File.open("#{@root}/etc/login.gov/info/env", 'w') { |f| f.puts 'staging' }
        end

        it 'reads the contents of the file' do
          expect(Identity::Hostdata.env).to eq('staging')
        end
      end

      context 'when the info/env file does not exist' do
        it 'blows up' do
          expect { Identity::Hostdata.env }.
            to raise_error(Identity::Hostdata::MissingConfigError)
        end
      end
    end

    context 'when the LOGIN_ENV env var is set' do
      before do
        stub_const(
          'ENV',
          { 'LOGIN_ENV' => 'dev', 'LOGIN_DATACENTER' => 'true' },
        )
      end

      it 'reads the value of the env var' do
        expect(Identity::Hostdata.env).to eq('dev')
      end
    end

    context 'when /etc/login.gov does not exist (development environment)' do
      it 'is nil' do
        expect(Identity::Hostdata.env).to eq(nil)
      end
    end
  end

  describe '.instance_role' do
    context 'when /etc/login.gov exists (in a datacenter environment)' do
      before { FileUtils.mkdir_p("#{@root}/etc/login.gov") }

      context 'when the info/role file exists' do
        before do
          FileUtils.mkdir_p("#{@root}/etc/login.gov/info")
          File.open("#{@root}/etc/login.gov/info/role", 'w') { |f| f.puts 'migration' }
        end

        it 'reads the contents of the file' do
          expect(Identity::Hostdata.instance_role).to eq('migration')
        end
      end

      context 'when the LOGIN_HOST_ROLE env var is set' do
        before do
          stub_const(
            'ENV',
            { 'LOGIN_HOST_ROLE' => 'worker', 'LOGIN_DATACENTER' => 'true' },
          )
        end

        it 'reads the value of the env var' do
          expect(Identity::Hostdata.instance_role).to eq('worker')
        end
      end

      context 'when the info/role file does not exist' do
        it 'blows up' do
          expect { Identity::Hostdata.instance_role }.
            to raise_error(Identity::Hostdata::MissingConfigError)
        end
      end
    end

    context 'when /etc/login.gov does not exist (development environment)' do
      it 'is nil' do
        expect(Identity::Hostdata.instance_role).to eq(nil)
      end
    end
  end

  describe '#aws_region' do
    context 'when the LOGIN_AWS_REGION env var is set' do
      it 'returns the env var value' do
        stub_const('ENV', 'LOGIN_AWS_REGION' => 'us-west-2')

        expect(Identity::Hostdata.aws_region).to eq('us-west-2')
      end
    end

    context 'when a region env var is not set' do
      it 'uses the EC2 instance metadata' do
        stub_request(:get, 'http://169.254.169.254/2016-09-02/dynamic/instance-identity/document').
          to_return(body: {
            'accountId' => '12345',
            'region' => 'us-east-1',
          }.to_json)

        expect(Identity::Hostdata.aws_region).to eq('us-east-1')
      end
    end
  end

  describe '#aws_account_id' do
    context 'when the LOGIN_AWS_ACCOUNT_ID env var is set' do
      it 'returns the env var value' do
        stub_const('ENV', 'LOGIN_AWS_ACCOUNT_ID' => '67890')

        expect(Identity::Hostdata.aws_account_id).to eq('67890')
      end
    end

    context 'when an account id env var is not set' do
      it 'uses the EC2 instance metadata' do
        stub_request(:get, 'http://169.254.169.254/2016-09-02/dynamic/instance-identity/document').
          to_return(body: {
            'accountId' => '12345',
            'region' => 'us-east-1',
          }.to_json)

        expect(Identity::Hostdata.aws_account_id).to eq('12345')
      end
    end
  end

  describe '.in_datacenter?' do
    it 'is true when the /etc/login.gov directory exists' do
      FileUtils.mkdir_p("#{@root}/etc/login.gov")

      expect(Identity::Hostdata.in_datacenter?).to eq(true)
    end

    it 'is true when the HOSTDATA_DATACENTER var is set to "true"' do
      stub_const('ENV', 'LOGIN_DATACENTER' => 'true')
    end

    it 'is false when the /etc/login.gov does not exist' do
      expect(Identity::Hostdata.in_datacenter?).to eq(false)
    end
  end

  describe '.in_datacenter' do
    context 'when the /etc/login.gov directory exists' do
      before { FileUtils.mkdir_p("#{@root}/etc/login.gov") }

      it 'blows up without a block' do
        expect { Identity::Hostdata.in_datacenter }.to raise_error(LocalJumpError)
      end

      it 'yields to its block with itself' do
        called = false

        Identity::Hostdata.in_datacenter do |hostdata|
          called = true

          expect(hostdata).to eq(Identity::Hostdata)
        end

        expect(called).to eq(true)
      end
    end

    context 'when the /etc/login.gov does not exist' do
      it 'blows up without a block' do
        expect { Identity::Hostdata.in_datacenter }.to raise_error(LocalJumpError)
      end

      it 'does not call its block (no-op)' do
        called = false

        Identity::Hostdata.in_datacenter { called = true }

        expect(called).to eq(false)
      end
    end
  end

  describe '.config' do
    let(:config_data) do
      {
        description: 'the staging data',
        default_attributes: {
          login_dot_gov: {
            idp_run_migrations: true,
          },
        },
      }
    end

    context 'when /etc/login.gov exists (in a datacenter environment)' do
      before { FileUtils.mkdir_p("#{@root}/etc/login.gov") }

      context 'when the info/env file exists' do
        before do
          FileUtils.mkdir_p("#{@root}/etc/login.gov/info")
          File.open("#{@root}/etc/login.gov/info/env", 'w') { |f| f.puts 'staging' }
          FileUtils.mkdir_p("#{@root}/etc/login.gov/repos/identity-devops/kitchen/environments/")
          File.open(
            "#{@root}/etc/login.gov/repos/identity-devops/kitchen/environments/staging.json", 'w'
          ) { |f| f.puts config_data.to_json }
        end

        it 'parses the contents of the file' do
          expect(Identity::Hostdata.config).to eq(config_data)
        end
      end

      context 'when the info/env file does not exist' do
        it 'blows up' do
          expect { Identity::Hostdata.config }.
            to raise_error(Identity::Hostdata::MissingConfigError)
        end
      end
    end

    context 'when the LOGIN_HOST_CONFIG env var is set' do
      before do
        stub_const(
          'ENV',
          {
            'LOGIN_HOST_CONFIG' => config_data.to_json,
            'LOGIN_DATACENTER' => 'true',
            'LOGIN_ENV' => 'staging',
          },
        )
      end

      it 'parses and returns the config in the env' do
        expect(Identity::Hostdata.config).to eq(config_data)
      end
    end

    context 'when /etc/login.gov does not exist (development environment)' do
      it 'is an empty hash' do
        expect(Identity::Hostdata.config).to eq({})
      end
    end
  end

  describe '.app_secrets_s3' do
    before do
      stub_request(:get, 'http://169.254.169.254/2016-09-02/dynamic/instance-identity/document').
        to_return(body: {
          'accountId' => '12345',
          'region' => 'us-east-1',
        }.to_json)

      FileUtils.mkdir_p("#{@root}/etc/login.gov/info")
      File.open("#{@root}/etc/login.gov/info/env", 'w') { |f| f.puts 'int' }
    end

    subject(:s3) { Identity::Hostdata.app_secrets_s3 }

    it 'creates an S3 instance with the app secrets bucket' do
      expect(s3.env).to eq('int')
      expect(s3.region).to eq('us-east-1')
      expect(s3.bucket).to eq('login-gov.app-secrets.12345-us-east-1')
    end

    context 'with an s3_client param' do
      let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }

      subject(:s3) { Identity::Hostdata.app_secrets_s3(s3_client: s3_client) }

      it 'passes s3_client through' do
        expect(s3.send(:s3_client)).to eq(s3_client)
      end
    end

    context 'with a logger param' do
      let(:logger) { Logger.new(STDOUT) }

      subject(:s3) { Identity::Hostdata.app_secrets_s3(logger: logger) }

      it 'passes the logger through' do
        expect(s3.logger).to eq(logger)
      end
    end
  end

  describe '.secrets_s3' do
    before do
      stub_request(:get, 'http://169.254.169.254/2016-09-02/dynamic/instance-identity/document').
        to_return(body: {
          'accountId' => '12345',
          'region' => 'us-east-1',
        }.to_json)

      FileUtils.mkdir_p("#{@root}/etc/login.gov/info")
      File.open("#{@root}/etc/login.gov/info/env", 'w') { |f| f.puts 'int' }
    end

    subject(:s3) { Identity::Hostdata.secrets_s3 }

    it 'creates an S3 instance with the secrets bucket' do
      expect(s3.env).to eq('int')
      expect(s3.region).to eq('us-east-1')
      expect(s3.bucket).to eq('login-gov.secrets.12345-us-east-1')
    end

    context 'with an s3_client param' do
      let(:s3_client) {  Aws::S3::Client.new(stub_responses: true) }

      subject(:s3) { Identity::Hostdata.secrets_s3(s3_client: s3_client) }

      it 'passes s3_client through' do
        expect(s3.send(:s3_client)).to eq(s3_client)
      end
    end

    context 'with a logger param' do
      let(:logger) { Logger.new(STDOUT) }

      subject(:s3) { Identity::Hostdata.secrets_s3(logger: logger) }

      it 'passes the logger through' do
        expect(s3.logger).to eq(logger)
      end
    end
  end

  describe '.logger' do
    it 'has a default value' do
      expect(Identity::Hostdata.logger).to be
    end

    it 'has a setter' do
      logger = Logger.new(STDOUT)

      Identity::Hostdata.logger = logger

      expect(Identity::Hostdata.logger).to eq(logger)
    end
  end
end

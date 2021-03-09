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

  describe '.setup_settings!' do
    before do
      stub_const('ENV', {})
    end

    it 'sets settings' do
      expect do
        Identity::Hostdata.setup_settings!(
          configuration: { 'some_key' => 'some_value'},
          rails_env: 'test',
        )
      end.to(
        change { Identity::Hostdata.settings }.from(nil).to(kind_of(Identity::Hostdata::Settings))
      )
    end

    it 'writes to ENV when write_to_env is true' do
      expect do
        Identity::Hostdata.setup_settings!(
          configuration: { 'some_key' => 'some_value'},
          rails_env: 'test',
          write_to_env: true,
        )
      end.to(change { ENV['some_key'] }.to('some_value'))
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

  describe '.in_datacenter?' do
    it 'is true when the /etc/login.gov directory exists' do
      FileUtils.mkdir_p("#{@root}/etc/login.gov")

      expect(Identity::Hostdata.in_datacenter?).to eq(true)
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

    context 'when /etc/login.gov does not exist (development environment)' do
      it 'is an empty hash' do
        expect(Identity::Hostdata.config).to eq({})
      end
    end
  end

  describe 'app_secrets_s3' do
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

  describe 'secrets_s3' do
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

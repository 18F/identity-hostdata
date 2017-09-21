require "spec_helper"

RSpec.describe Identity::Hostdata do
  it "has a version number" do
    expect(Identity::Hostdata::VERSION).not_to be nil
  end

  context 'reading config from the filesystem' do
    around(:each) do |ex|
      Identity::Hostdata.reset!

      FakeFS.with_fresh do
        ex.run
      end
    end

    describe '.domain' do
      context 'when /etc/login.gov exists (in a datacenter environment)' do
        before { FileUtils.mkdir_p('/etc/login.gov') }

        context 'when the info/domain file exists' do
          before do
            FileUtils.mkdir_p('/etc/login.gov/info')
            File.open('/etc/login.gov/info/domain', 'w') { |f| f.puts 'identitysandbox.gov' }
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
        before { FileUtils.mkdir_p('/etc/login.gov') }

        context 'when the info/env file exists' do
          before do
            FileUtils.mkdir_p('/etc/login.gov/info')
            File.open('/etc/login.gov/info/env', 'w') { |f| f.puts 'staging' }
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

    describe '.in_datacenter?' do
      it 'is true when the /etc/login.gov directory exists' do
        FileUtils.mkdir_p('/etc/login.gov')

        expect(Identity::Hostdata.in_datacenter?).to eq(true)
      end

      it 'is false when the /etc/login.gov does note exist' do
        expect(Identity::Hostdata.in_datacenter?).to eq(false)
      end
    end
  end
end

require 'spec_helper'

RSpec.describe Identity::Hostdata::EC2 do
  describe '.load' do
    subject(:load) { Identity::Hostdata::EC2.load }

    let(:ec2_api_token) { SecureRandom.hex }

    it 'loads data from the magic ECS URL' do
      stub_request(:put, 'http://169.254.169.254/latest/api/token').
          with(headers: { 'X-Aws-Ec2-Metadata-Token-Ttl-Seconds' => '60' }).
          to_return(body: ec2_api_token)
      stub_request(:get, 'http://169.254.169.254/2016-09-02/dynamic/instance-identity/document').
        with(headers: { 'X-aws-ec2-metadata-token' => ec2_api_token }).
        to_return(body: document.to_json)

      ec2 = load
      expect(ec2.region).to eq('us-west-2')
    end

    it 'blows up when the request times out' do
      stub_request(:put, 'http://169.254.169.254/latest/api/token').
          with(headers: { 'X-Aws-Ec2-Metadata-Token-Ttl-Seconds' => '60' }).
          to_return(body: ec2_api_token)
      stub_request(:get, 'http://169.254.169.254/2016-09-02/dynamic/instance-identity/document').
        with(headers: { 'X-aws-ec2-metadata-token' => ec2_api_token }).
        to_timeout

      expect { load }.to raise_error(Net::OpenTimeout)
    end
  end

  let(:document) do
    {
      'privateIp' => '172.16.33.170',
      'devpayProductCodes' => nil,
      'availabilityZone' => 'us-west-2b',
      'version' => '2010-08-31',
      'instanceId' => 'i-12345',
      'billingProducts' => nil,
      'instanceType' => 'c3.xlarge',
      'accountId' => '12345',
      'architecture' => 'x86_64',
      'kernelId' => nil,
      'ramdiskId' => nil,
      'imageId' => 'ami-7e22c506',
      'pendingTime' => '2017-08-24T18:10:24Z',
      'region' => 'us-west-2',
    }
  end

  subject(:ec2) { Identity::Hostdata::EC2.new(document) }

  describe '#region' do
    subject(:region) { ec2.region }

    it { is_expected.to eq('us-west-2') }
  end

  describe '#account_id' do
    subject(:account_id) { ec2.account_id }

    it { is_expected.to eq('12345') }
  end
end

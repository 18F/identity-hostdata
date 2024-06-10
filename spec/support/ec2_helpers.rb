module Ec2Helpers
  def stub_ec2_metadata(ec2_api_token: SecureRandom.hex, document: nil)
    document ||= {
      'accountId' => '12345',
      'region' => 'us-east-1',
    }

    stub_request(:put, 'http://169.254.169.254/latest/api/token').
      with(headers: { 'X-Aws-Ec2-Metadata-Token-Ttl-Seconds' => '60' }).
      to_return(body: ec2_api_token)
    stub_request(:get, 'http://169.254.169.254/2016-09-02/dynamic/instance-identity/document').
      with(headers: { 'X-aws-ec2-metadata-token' => ec2_api_token }).
      to_return(body: document.to_json)
  end
end

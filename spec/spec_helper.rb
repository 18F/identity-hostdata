require "bundler/setup"
require "identity/hostdata"
require "pp"
require "identity/hostdata/fake_s3_client"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

require 'webmock/rspec'
WebMock.disable_net_connect!

require "bundler/setup"
require "identity/hostdata"
require "pp"
require "support/ec2_helpers"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include(Ec2Helpers)
end

require 'webmock/rspec'
WebMock.disable_net_connect!

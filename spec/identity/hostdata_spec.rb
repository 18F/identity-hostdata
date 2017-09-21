require "spec_helper"

RSpec.describe Identity::Hostdata do
  it "has a version number" do
    expect(Identity::Hostdata::VERSION).not_to be nil
  end

  it "does something useful" do
    expect(false).to eq(true)
  end
end

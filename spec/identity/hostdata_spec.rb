RSpec.describe 'backwards-compatible name' do
  it 'exists' do
    expect do
      require 'login_gov/hostdata'
      LoginGov::Hostdata.env
    end.to_not raise_error
  end
end

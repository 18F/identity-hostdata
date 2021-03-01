require 'identity/hostdata'

# Create an alias with the old LoginGov namespace so we don't break some of our configs
module LoginGov
  Hostdata = ::Identity::Hostdata
end

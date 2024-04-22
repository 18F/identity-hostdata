# Identity::Hostdata (`identity-hostdata`)

A gem to help read configuration from login.gov infrastructure, according to the [login.gov infrastructure contract][contract].

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'identity-hostdata', github: '18F/identity-hostdata'
```

## Usage

Use this gem to access config data on a per-host basis. The config data is read according to the [login.gov infrastructure contract][contract].

```ruby
require 'identity/hostdata'

Identity::Hostdata.domain
# => "login.gov"
```

Set configs from YML files in S3

```ruby
Identity::Hostdata.load_config!(
  app_root: Rails.root,
  rails_env: Rails.env
) do |builder|
  builder.add(:some_option, type: :string)
  builder.add(:other_option, type: :json)
end

Identity::Hostdata.config.some_option
# => "value"
```

Download configs from S3:

```ruby
root = File.expand_path('../../', __FILE__)

Identity::Hostdata.in_datacenter do |hostdata|
  # Download the config and write to disk
  hostdata.app_secrets_s3.download_file(
    s3_path: '/%{env}/v1/idp/database.yml',
    local_path: File.join(root, 'config/database_s3.yml')
  )
  # Read the config into the `cert` var
  cert = hostdata.secrets_s3.read_file('/%{env}/oidc.cert')
end
```

[contract]: docs/contract.md

## Development

Run tests:

```
make test
```

## Contributing

See [CONTRIBUTING](CONTRIBUTING.md) for additional information.

## Public domain

This project is in the worldwide [public domain](LICENSE.md). As stated in [CONTRIBUTING](CONTRIBUTING.md):

> This project is in the public domain within the United States, and copyright and related rights in the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).
>
> All contributions to this project will be released under the CC0 dedication. By submitting a pull request, you are agreeing to comply with this waiver of copyright interest.

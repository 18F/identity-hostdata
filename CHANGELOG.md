# 4.3.0

- Remove support for role-based configuration

# 4.2.0

- Add Secrets Manager as a source for configuration values

# 4.1.0

- Add AWS Secrets Manager support to `ConfigBuilder#add`

# 4.0.0

- **Breaking Change**: `Identity::Hostdata.config` is renamed to `Identity::Hostdata.host_config`

- **Breaking Change**: `LoginGov` namespace removed

- New wrapper around S3 configs: `Identity::Hostdata.config`

# 3.2.0

- Update to use V2 of the EC2 instance metadata service

# 3.1.2

- Fix a bug where the migration application.yml path was not resolved correctly

# 3.1.1

- Fix a bug where the dashboard application.yml path was not resolved correctly

# 3.1.0

- Add a ConfigReader class which can be used to parse configs from application.yml

# 3.0.0

- Add the ability to override hostdata values with env vars

# 2.0.0

- Change the API that negotiates with S3 to differentiate between the secrets
  bucket and the app-secrets bucket

# 1.0.1

- Add backwards-compatible `LoginGov` namespace back to smooth out
  transition in config repo

# 1.0.0

- Rename `LoginGov` namespace back to `Identity` (big breaking change)

# 0.4.3

- Added `LoginGov::Hostdata.config`

# 0.4.1

- Patch memoization bug in `instance_role`

# 0.4.0

- Added `LoginGov::Hostdata.instance_role`

# 0.3.3

- Use `Hash#fetch` in `LoginGov::Hostdata::EC2` so that EC2 metadata methods
  will not return nil if required keys are absent.

# 0.3.2

- Allow overriding `s3_client` in `LoginGov::Hostdata.s3`
- Expose `LoginGov::Hostdata::FakeS3Client`

# 0.3.1 (2017-09-25)

- Fix circular reference warning

# 0.3.0 (2017-09-22)

- Added `LoginGov::Hostdata.in_datacenter`
- Added `LoginGov::Hostdata::EC2`
- Added `LoginGov::Hostdata::S3`

# 0.2.0 (2017-09-21)

Renamed `Identity` to `LoginGov` because `Identity` because of a name collision with the `identities` table ActiveRecord model in `identity-idp`

- Added `LoginGov::Hostdata.domain`
- Added `LoginGov::Hostdata.env`

# 0.1.0 (2017-09-21)

- Added `Identity::Hostdata.domain`
- Added `Identity::Hostdata.env`

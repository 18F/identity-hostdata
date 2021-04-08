# login.gov infrastructure contract

This gem is built to support an app in 2 deployment schemes:

1. In a chef provisioned environment using EC2 metadata and files on the disk
2. In a non-chef provisioned environment that is configured using environment variables

## Host configurations

In a chef configured environment, this gem can read configurations from files that are added
to `/etc/login.gov` by chef.

Outside of a chef configured environment, this gem will use env vars for configuration

The `/etc/login.gov` directory or env vars can be accessed through `Identity::Hostdata` class methods.

| File | Env var | API | Example |
| ---- | --- | ------- |
| `/etc/login.gov/info/env` | `LOGIN_ENV` | `Identity::Hostdata.env` | `"int"` |
| `/etc/login.gov/info/domain` | `LOGIN_DOMAIN` | `Identity::Hostdata.domain` | `"login.gov"` |
| `/etc/login.gov/info/role` | `LOGIN_HOST_ROLE` | `Identity::Hostdata.instance_role` | `"login.gov"` |
| `/etc/login.gov/repos/identity-devops/kitchen/environments/$ENV.json` | LOGIN_HOST_CONFIG | `Identity::Hostdata.config` | `"login.gov"` |

Additionally, if env vars are being used you will want to set `LOGIN_DATACENTER` to true in production. This will make `Identity::Hostdata.in_datacenter?` return true.

### Configuration via env vars

To configure the app with env vars, add the following environment variables:

- `LOGIN_DATACENTER`: The value `true` to indicate the IDP is in production in a deployed environment
- `LOGIN_ENV`: The environment the app is running in (e.g. `int`, `staging`, or `prod`)
- `LOGIN_DOMAIN`: The domain of the current app (e.g. `idp.int.identitysandbox.gov`)
- `LOGIN_HOST_ROLE`: The role of the current host, (e.g. `idp`, `workder`, `pivcac`)
- `LOGIN_HOST_CONFIG`: Host specific configurations (A template is available here: [https://github.com/18F/identity-devops/blob/main/kitchen/environments/environment.json.template](https://github.com/18F/identity-devops/blob/main/kitchen/environments/environment.json.template))

## AWS host information

Apps may need to know about the AWS environment they are configured to run in or alongside.
If the app is running on an EC2 instance in AWS, it can read the EC2 metadata to determine the region or account ID.
If the app is not running on an EC2 instance in AWs, it can read configurations from ENV vars

### EC2 instance metadata

We use [instance metadata][instance-metadata] (an HTTP request from an EC2 box) to populate basic information about our instances in EC2.

- region
- account ID

The [Identity::Hostdata](../lib/identity/hostdata/hostdata.rb) module helps load and read this data:

```ruby
Identity::Hostdata.aws_region
# => "us-west-1"
Identity::Hostdata.aws_account_id
# => "12345"
```

[instance-metadata]: http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html

### AWS environment vars

If the app is not running on an EC2 instance, then the configs for the AWS environment can be set with the following env vars:

- `LOGIN_AWS_REGION`: The AWS region (named to avoid conflicting with `AWS_REGION`)
- `LOGIN_AWS_ACCOUNT_ID`: The AWS account ID

## Files stored in S3

We store config data (meant to be changed by app developers) in S3 buckets, with top-level directories per environment.

The bucket names can correspond to account IDs and regions:

```ruby
"login-gov.app-secrets.#{ec2.account_id}-#{ec2.region}"
```

The [Identity::Hostdata::S3](../lib/identity/hostdata/s3.rb) class helps manage access to data in these buckets, and the `Identity::Hostdata.s3` convenience method helps build S3 instances and download remote config files locally:

```ruby
s3 = Identity::Hostdata.s3
# downloads the `foobar.yml` file for the current environment to local path `config/foobar.yml`
s3.download_configs(
  '%{env}/idp/v1/foobar.yml' => 'config/foobar.yml'
)
```

# login.gov infrastructure contract

## `/etc/login.gov`

The `/etc/login.gov` directory will exist on deployed instanes of login.gov apps. It contains individual files with useful data, and can be accessed through `Identity::Hostdata` class methods

| File | API | Example |
| ---- | --- | ------- |
| `/etc/login.gov/info/env` | `Identity::Hostdata.env` | `"int"` |
| `/etc/login.gov/info/domain` | `Identity::Hostdata.domain` | `"login.gov"` |

## EC2 instance metadata

We use [instance metadata][instance-metadata] (an HTTP request from an EC2 box) to populate basic information about our instances in EC2.

- region
- account ID

The [Identity::Hostdata::EC2](../lib/identity/hostdata/ec2.rb) class helps load and read this data:

```ruby
ec2_data = Identity::Hostdata::EC2.load
# => #<Identity::Hostdata::EC2:0x00007fc49dd30f40 ...>
ec2_data.region
# => "us-west-1"
ec2_data.account_id
# => "12345"
```

[instance-metadata]: http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html

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

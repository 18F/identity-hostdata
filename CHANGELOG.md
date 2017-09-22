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

# elk

Puppet control repo for a compact, Hiera-driven Elastic Stack lab.

The default role provisions Filebeat, Logstash, Elasticsearch, Kibana, and Nginx
on a supported EL-family host. It is intended for local development, integration
testing, and demonstration of a roles-and-profiles Puppet control repo.

## Target

- Puppet 8
- Ruby 3.x for local tooling
- Elastic Stack 8 package repositories
- Rocky/EL 9 style hosts
- One Elasticsearch service per node
- Hiera-managed profile data
- RSpec catalog tests and Beaker acceptance tests

## Architecture

```text
                 +-------------------+
                 |  Managed log file |
                 |  /var/log/messages|
                 |  /var/log/testlog |
                 +---------+---------+
                           |
                           v
                    +-------------+
                    |  Filebeat   |
                    | filestream  |
                    +------+------+             HTTP :80
                           |                         ^
                           | Beats :5044             |
                           v                         |
                    +-------------+           +------+------+
                    |  Logstash   |           |    Nginx    |
                    | main pipe   |           | reverse     |
                    +------+------+           | proxy       |
                           |                  +------+------+
                           | HTTP :9200              |
                           v                         |
                 +---------+---------+               |
                 | Elasticsearch     |               |
                 | single node       |               |
                 | ILM + templates   |               |
                 +---------+---------+               |
                           ^                         |
                           | HTTP :9200              |
                           |                         v
                    +------+------+           HTTP :5601
                    |   Kibana    |<------------------+
                    | dashboards  |
                    +-------------+
```

The stack is intentionally direct: Filebeat ships to Logstash, Logstash writes
to Elasticsearch, Kibana reads from Elasticsearch, and Nginx fronts Kibana.

## Module Set

The control repo pins the Vox Pupuli Elastic module line:

```puppet
mod 'puppet/elastic_stack', '10.0.0'
mod 'puppet/elasticsearch', '10.0.0'
mod 'puppet/logstash', '9.0.0'
mod 'puppet/kibana', '9.0.0'
```

Supporting modules are pinned in `spec/fixtures/Puppetfile` and `.fixtures.yml`
so local catalog tests and CI resolve the same dependency set.

## Repository Layout

- `site/modules/role`: role classes that compose profiles
- `site/modules/profile`: profile classes and managed files/templates
- `spec/fixtures/hieradata`: sample Hiera data for the lab stack
- `spec/classes`: catalog tests
- `spec/acceptance`: Beaker acceptance tests
- `.github/workflows`: CI checks

## Local Checks

Install Ruby dependencies:

```shell
bundle install
```

Run syntax, lint, and catalog tests:

```shell
bundle exec rake unit
```

Run acceptance tests against the Vagrant nodeset:

```shell
BEAKER_destroy=no bundle exec rspec spec/acceptance
```

## Security Note

The sample Hiera disables Elasticsearch security to keep the single-node lab
easy to apply and test:

```yaml
profile::elasticsearch::data_node::config:
  'xpack.security.enabled': false
```

Do not use that setting for production. A production deployment should manage
TLS, credentials, Kibana service authentication, snapshots, and lifecycle
policies explicitly.

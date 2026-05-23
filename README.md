# elk

#### Table of contents

1. [Intro](#intro)
2. [Target](#target)
3. [Architecture](#architecture)
4. [Module Set](#module-set)
5. [Repository Layout](#repository-layout)
6. [Azure Topologies](#azure-topologies)
    * [One-Node Topology](#one-node-topology)
        - [Architecture](#architecture-2)
        - [Deployment](#deployment)
    * [Multi-Node Topology](#multi-node-topology)
7. [Testing](#testing)
8. [Security Note](#security-note)
9. [License](#license)

## Intro

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
- RSpec catalog tests and Litmus acceptance tests

## Architecture

```text
                 +---------------------+
                 |  Managed log file   |
                 |  /var/log/messages  |
                 |  /var/log/testlog   |
                 +---------+-----------+
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

Supporting stack modules are pinned in `spec/fixtures/Puppetfile` and
`.fixtures.yml` so local catalog tests and CI resolve the same dependency set.
Litmus utility modules are pulled from their upstream GitHub repositories by
`.fixtures.yml`.

## Repository Layout

- `site/modules/role`: role classes that compose profiles
- `site/modules/profile`: profile classes and managed files/templates
- `spec/fixtures/hieradata`: sample Hiera data for the lab stack
- `spec/classes`: catalog tests
- `spec/acceptance`: Litmus acceptance tests
- `.github/workflows`: CI checks

## Azure Topologies

Each Azure deployment topology lives in its own directory under `infra/`. The
current topology is `infra/azure-one-node`; a future multi-node topology can be
added as `infra/azure-multi-node` without reshaping the one-node test target.

Create the shared resource group once before deploying a topology:

```bash
bundle exec rake azure:resource_group
```

Destroy the lab resource group when finished:

```bash
bundle exec rake azure:destroy
```

### One-Node Topology

The `infra/azure-one-node` Bicep template provisions a single EL9-compatible
Azure VM for end-to-end testing on real systemd/package infrastructure.

#### Architecture

```text
                         Azure subscription
                                |
                                v
                    +-----------------------+
                    | Resource group        |
                    | rg-elk-lab            |
                    +-----------+-----------+
                                |
              +-----------------+-----------------+
              |                                   |
              v                                   v
   +---------------------+             +---------------------+
   | Virtual network     |             |     Public IP       |
   | 10.42.0.0/16        |             |      static         |
   +----------+----------+             +----------+----------+
              |                                   |
              v                                   |
   +---------------------+                        |
   | Subnet              |                        |
   | 10.42.1.0/24        |                        |
   +----------+----------+                        |
              |                                   |
              v                                   |
   +---------------------+                        |
   | Network security    |                        |
   | group               |                        |
   | SSH/HTTP/ELK ports  |                        |
   | from LAPTOP_IP only |                        |
   +----------+----------+                        |
              |                                   |
              v                                   v
        +-----+-----------------------------------+-----+
        | Network interface                             |
        +----------------------+------------------------+
                               |
                               v
        +-----------------------------------------------+
        | AlmaLinux 9 VM                                |
        | one-node ELK stack                            |
        | OS disk + managed data disk at LUN 0          |
        | cloud-init: packages, iptables, vm.max_map    |
        | facts: espv + elk_lab_source_cidr             |
        | Puppet acceptance target                      |
        +-----------------------------------------------+
```

#### Deployment

Before deploying, replace the placeholder SSH key in
`infra/azure-one-node/main.bicepparam` and export `LAPTOP_IP` with your current
public IPv4 address. The parameter file appends `/32` automatically so the
Azure NSG and host firewall open only for that single IP.

```bash
export LAPTOP_IP=<your-public-ipv4>
```

The default image is AlmaLinux 9 because it is EL9-compatible and available as a
straightforward Azure Marketplace image; the image publisher, offer, SKU, and
version are parameters so a Rocky 9 image can be used instead where desired.

The one-node template also attaches a managed data disk at LUN 0. Cloud-init
publishes that Azure LUN symlink as the `espv` external fact, so
`profile::elasticsearch::data_node` can build the Elasticsearch LVM volume at
`/srv/es` without relying on volatile `/dev/sd*` device names. Cloud-init also
publishes `elk_lab_source_cidr` from the same `LAPTOP_IP`-derived CIDR used by
the Azure network security group, so Puppet opens the lab ports only to that
trusted client on the VM firewall.

Log in to Azure and choose the subscription:

```bash
az login
az account set --subscription <subscription-id-or-name>
```

Then to deploy:

```bash
bundle exec rake azure:one_node:build
bundle exec rake azure:one_node:validate
bundle exec rake azure:one_node:deploy
bundle exec rake azure:one_node:outputs
```

The Azure tasks require `LAPTOP_IP` and use these additional environment
variables when you want to override the common defaults:

```bash
LAPTOP_IP=<your-public-ipv4>
AZURE_RESOURCE_GROUP=rg-elk-lab
AZURE_LOCATION=australiaeast
```

The one-node tasks use these additional environment variables:

```bash
AZURE_ONE_NODE_DEPLOYMENT_NAME=elk-one-node
AZURE_ONE_NODE_TEMPLATE_FILE=infra/azure-one-node/main.bicep
AZURE_ONE_NODE_PARAMETERS_FILE=infra/azure-one-node/main.bicepparam
AZURE_ONE_NODE_BUILD_DIR=/tmp/elk-azure-one-node-bicep
```

The deployment output includes the public IP and SSH command. The next testing
step is to turn those outputs into a Litmus/Bolt inventory entry so the
acceptance specs can target the Azure VM directly.

### Multi-Node Topology

Not implemented yet. The intended home is `infra/azure-multi-node`, with its
own Bicep template, parameter file, README notes, and Rake tasks under
`azure:multi_node:*`.

## Testing

Install Ruby dependencies:

```bash
bundle install
```

Run syntax, lint, and catalog tests:

```bash
bundle exec rake unit
```

Run the Azure static checks. These lint the Bicep template, validate the
cloud-init schema, compile the Bicep template and parameter file, and run RSpec
assertions against the compiled ARM JSON:

```bash
export LAPTOP_IP=<your-public-ipv4>
bundle exec rake azure:one_node:static
```

The Azure static check is equivalent to running these individual checks:

```bash
bundle exec rake azure:one_node:lint
bundle exec rake azure:one_node:cloud_init_schema
bundle exec rake azure:one_node:assert_compiled
```

Acceptance tests are intended to run against the Azure VM created by the Bicep
deployment. The next step is to generate `spec/fixtures/litmus_inventory.yaml`
from `bundle exec rake azure:one_node:outputs`, install the Puppet 8 agent on
that target, and run:

```bash
TARGET_HOST=<azure-target-name> bundle exec rspec spec/acceptance/role_elk_stack_spec.rb
```

## Security Note

The sample Hiera disables Elasticsearch security to keep the single-node lab
easy to apply and test:

```yaml
profile::elasticsearch::data_node::config:
  'xpack.security.enabled': false
```

Do not use that setting for production. The lab narrows Azure NSG and host
iptables access to `LAPTOP_IP`, but Elasticsearch security is still disabled. A
production deployment should manage TLS, credentials, Kibana service
authentication, snapshots, and lifecycle policies explicitly.

## License

MIT.

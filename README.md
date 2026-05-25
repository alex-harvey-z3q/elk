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
        - [Architecture](#architecture-3)
        - [Deployment](#deployment-2)
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
                 | lab security off  |               |
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

Each Azure deployment topology lives in its own directory under `infra/`.
The current topologies are `infra/azure-one-node` and
`infra/azure-multi-node`.

For manual deployment and iteration, create the shared resource group before
deploying a topology:

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

Before deploying, export the two values that are intentionally local to your
machine: your current public IPv4 address and the SSH public key Azure should
install for the VM admin user. The parameter file appends `/32` to `LAPTOP_IP`
automatically so the Azure NSG and host firewall open only for that single IP.

```bash
export LAPTOP_IP=<your-public-ipv4>
export AZURE_ONE_NODE_ADMIN_SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)"
```

The one-node topology otherwise uses fixed lab values recorded in
`infra/azure-one-node/main.bicepparam`: resource group `rg-elk-lab`, location
`australiaeast`, deployment name `elk-one-node`, admin user `azureuser`, VM size
`Standard_D4s_v4`, AlmaLinux 9, and a 128 GiB managed data disk.

The one-node template also attaches a managed data disk at LUN 0. Cloud-init
resolves that Azure LUN symlink and publishes the resulting block device as the
`espv` external fact, so `profile::elasticsearch::data_node` can build the
Elasticsearch LVM volume at `/srv/es`. Cloud-init also publishes
`elk_lab_source_cidr` from the same `LAPTOP_IP`-derived CIDR used by the Azure
network security group, so Puppet opens the lab ports only to that trusted
client on the VM firewall.

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

The deployment output includes the public IP and SSH command.

If your public IP changes after the VM has been created, update the lab
allow-list instead of redeploying the VM. Azure does not allow `customData` to
change after VM creation, and the one-node bootstrap data includes the source
CIDR used by Puppet firewall facts.

```bash
export LAPTOP_IP="$(curl -s https://ifconfig.me)"
bundle exec rake azure:one_node:update_source_ip
```

### Multi-Node Topology

#### Architecture

The `infra/azure-multi-node` Bicep template provisions four AlmaLinux 9 VMs
for a distributed ELK lab:

```text
                         Azure subscription
                                |
                                v
                    +-----------------------+
                    | Resource group        |
                    | rg-elk-lab            |
                    +-----------+-----------+
                                |
                                v
                    +-----------------------+
                    | Virtual network       |
                    | 10.43.0.0/16          |
                    +-----------+-----------+
                                |
                                v
                    +-----------------------+
                    | Subnet                |
                    | 10.43.1.0/24          |
                    +-----------+-----------+
                                |
                                v
                    +-----------------------+
                    | Network security      |
                    | group                 |
                    | SSH from LAPTOP_IP    |
                    | ELK ports internal    |
                    +-----------+-----------+
                                |
          +---------------------+---------------------+
          |                     |                     |
          v                     v                     v
 +----------------+    +----------------+    +----------------+
 | Elasticsearch  |    | Logstash       |    | Kibana         |
 | 10.43.1.10     |<---| 10.43.1.11     |    | 10.43.1.12     |
 | data disk LUN0 |    | Beats :5044    |    | HTTP :5601     |
 +----------------+    +----------------+    +----------+-----+
                                                        ^
                                                        |
                                                +-------+--------+
                                                | Edge / Nginx   |
                                                | 10.43.1.13     |
                                                | HTTP :80       |
                                                +----------------+
```

Each VM gets its own public IP for SSH during lab work, with SSH and exposed lab
ports restricted to `LAPTOP_IP`. The NSG also allows the ELK ports within the
lab subnet so the nodes can communicate over their private addresses.

The multi-node Puppet role uses the `elk_lab_role` external fact written by
cloud-init to choose the correct node profile. Elasticsearch, Logstash, Kibana,
and Edge/Nginx nodes use role-specific Hiera data under
`spec/fixtures/hieradata/roles`.

#### Deployment

Export the multi-node SSH key input, then build, validate, deploy, and inspect
the topology:

```bash
export LAPTOP_IP=<your-public-ipv4>
export AZURE_MULTI_NODE_ADMIN_SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)"
bundle exec rake azure:resource_group
bundle exec rake azure:multi_node:build
bundle exec rake azure:multi_node:validate
bundle exec rake azure:multi_node:deploy
bundle exec rake azure:multi_node:outputs
```

## Testing

Install Ruby dependencies:

```bash
bundle install
```

Run static checks and catalog tests:

```bash
bundle exec rake test
```

Run the Azure static checks. These lint the Bicep template, validate the
cloud-init schema, compile the Bicep template and parameter file, and run RSpec
assertions against the compiled ARM JSON:

```bash
export LAPTOP_IP=<your-public-ipv4>
export AZURE_ONE_NODE_ADMIN_SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)"
bundle exec rake azure:one_node:static
```

The Azure static check is equivalent to running these individual checks:

```bash
bundle exec rake azure:one_node:lint
bundle exec rake azure:one_node:cloud_init_schema
bundle exec rake azure:one_node:assert_compiled
```

Run the multi-node Azure static checks:

```bash
export LAPTOP_IP=<your-public-ipv4>
export AZURE_MULTI_NODE_ADMIN_SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)"
bundle exec rake azure:multi_node:static
```

Run acceptance tests on fresh Azure infrastructure and clean up afterwards:

```bash
export LAPTOP_IP="$(curl -s https://ifconfig.me)"
export AZURE_ONE_NODE_ADMIN_SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)"
bundle exec rake azure:one_node:acceptance_ephemeral
```

That task creates the resource group, validates and deploys the one-node
topology, runs the acceptance tests, then deletes the resource group and waits
until Azure reports it has gone.

To run the acceptance tests against an existing Azure VM created by the Bicep
deployment:

```bash
bundle exec rake azure:one_node:acceptance
```

That task writes `spec/fixtures/litmus_inventory.yaml` from the Azure resources,
checks SSH connectivity, installs the Puppet 8 agent with Litmus, stages the
control repo fixtures on the VM, applies `role::elk_stack`, and runs
`spec/acceptance/role_elk_stack_spec.rb`.

The acceptance flow can also be run in smaller steps:

```bash
bundle exec rake azure:one_node:inventory
bundle exec rake azure:one_node:source_ip
bundle exec rake azure:one_node:check_connectivity
bundle exec rake azure:one_node:install_agent
TARGET_HOST=<public-ip> bundle exec rspec spec/acceptance/role_elk_stack_spec.rb
```

Run multi-node acceptance tests on fresh Azure infrastructure and clean up
afterwards:

```bash
export LAPTOP_IP="$(curl -s https://ifconfig.me)"
export AZURE_MULTI_NODE_ADMIN_SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)"
bundle exec rake azure:multi_node:acceptance_ephemeral
```

To run the multi-node acceptance tests against an existing deployment:

```bash
bundle exec rake azure:multi_node:acceptance
```

That task writes a Litmus inventory with all four Azure VMs, checks SSH
connectivity, installs the Puppet 8 agent on each VM, stages the control repo
fixtures, applies `role::elk_multi_node`, and runs
`spec/acceptance/role_elk_multi_node_spec.rb`. The acceptance spec checks the
role-specific services and cross-node configuration for Elasticsearch,
Logstash, Kibana, and Edge/Nginx.

The multi-node acceptance flow can also be run in smaller steps:

```bash
bundle exec rake azure:multi_node:inventory
bundle exec rake azure:multi_node:source_ip
bundle exec rake azure:multi_node:check_connectivity
bundle exec rake azure:multi_node:install_agent
bundle exec rspec spec/acceptance/role_elk_multi_node_spec.rb
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

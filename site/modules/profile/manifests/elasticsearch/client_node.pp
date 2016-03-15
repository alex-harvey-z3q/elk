class profile::elasticsearch::client_node (
  Hash $firewall_multis,
  Hash $config,
  Hash $init_defaults,
) {
  create_resources(firewall_multi, $firewall_multis)

  include elasticsearch
  include profile::elasticsearch
  $cluster_name = $config['cluster.name']
  elasticsearch::instance { "${cluster_name}-client-instance":
    init_defaults => $init_defaults,
    config        => $config,
  }
}

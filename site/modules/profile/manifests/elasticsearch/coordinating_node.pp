class profile::elasticsearch::coordinating_node (
  Hash[String, Hash] $firewall_multis,
  Hash $config,
  Hash $init_defaults,
) {

  # Users of this profile should always allow this class to configure ES as a
  # client node.
  #
  ['node.master', 'node.data', 'node.ingest'].each |String $key| {
    if has_key($config, $key) {
      fail("Do not specify ${key} in ${module_name}")
    }
  }

  create_resources(firewall_multi, $firewall_multis)

  include elasticsearch
  include profile::elasticsearch

  $cluster_name = $config['cluster.name']

  elasticsearch::instance { "${cluster_name}-coordinating-instance":
    init_defaults => $init_defaults,
    config        => merge($config, {
      'node.master' => false,
      'node.data'   => false,
      'node.ingest' => false,
    }),
  }
}

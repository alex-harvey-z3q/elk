class profile::elasticsearch::coordinating_node (
  Hash[String, Hash] $firewall_multis = {},
  Hash               $config          = {},
) {
  create_resources(firewall_multi, $firewall_multis)

  warning('profile::elasticsearch::coordinating_node is deprecated: puppet/elasticsearch 7+ manages one Elasticsearch service per node. Use a dedicated host with node.roles => [] if you need a coordinating-only node.')
}

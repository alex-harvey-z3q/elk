class profile::elasticsearch::data_node (
  String $datadir,
  Hash $firewall_multis,
  Hash $volume_groups,
  Hash $config,
  Hash $init_defaults,
  Hash $es_templates,
  Hash $es_plugins,
  Hash $curator_jobs,
  Array $jvm_options,
  Integer[0,1] $vm_swappiness,
  Integer $vm_max_map_count,
) {
  assert_type(Stdlib::Absolutepath, $facts['espv'])

  create_resources(firewall_multi, $firewall_multis)
  create_resources(lvm::volume_group, $volume_groups)

  include elasticsearch
  include profile::elasticsearch

  $cluster_name = $config['cluster.name']

  elasticsearch::instance { $cluster_name:
    config        => $config,
    datadir       => $datadir,
    init_defaults => $init_defaults,
    jvm_options   => $jvm_options,
  }
  Mount[$datadir] -> File[$datadir]

  create_resources(elasticsearch::template, $es_templates)
  create_resources(elasticsearch::plugin, $es_plugins)

  package { 'elastic-curator':
    ensure => installed,
  }
  create_resources(cron, $curator_jobs)

  sysctl { 'vm.swappiness': value => $vm_swappiness }
  ->
  sysctl { 'vm.max_map_count': value => $vm_max_map_count }
  ->
  Service["elasticsearch-instance-${cluster_name}"]
}

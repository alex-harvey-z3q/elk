class profile::elasticsearch::data_node (
  String $datadir,
  Hash $firewall_multis,
  Hash $volume_groups,
  Hash $config,
  Hash $init_defaults,
  Hash $es_templates,
  Hash $es_plugins,
  Hash $curator_jobs,
  Integer[0,1] $vm_swappiness,
) {
  validate_absolute_path($::espv)

  create_resources(firewall_multi, $firewall_multis)
  create_resources(lvm::volume_group, $volume_groups)

  include elasticsearch
  include profile::elasticsearch

  $cluster_name = $config['cluster.name']

  elasticsearch::instance { $cluster_name:
    init_defaults => $init_defaults,
    config        => $config,
    datadir       => $datadir,
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
  Service["elasticsearch-instance-${cluster_name}"]
}

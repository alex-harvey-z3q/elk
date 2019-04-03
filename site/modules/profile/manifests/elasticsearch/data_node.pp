class profile::elasticsearch::data_node (

  # Mandatory params.
  Stdlib::Absolutepath     $datadir,
  Hash[String, Hash]       $firewall_multis,

  # Volume groups.
  Hash[String, Struct[{
    physical_volumes => Array[String],
    logical_volumes  => Hash[String, Struct[{
      mountpath      => Stdlib::Absolutepath
    }]]
  }]]                      $volume_groups,

  # Optional params.
  Hash                     $config                  = {},
  Hash                     $init_defaults           = {},
  Hash                     $es_plugins              = {},
  Hash                     $curator_jobs            = {},
  Array[Pattern[/^-/]]     $jvm_options             = [],
  Integer[0,1]             $vm_swappiness           = undef,
  Integer                  $vm_max_map_count        = undef,

  # ES templates.
  Hash[String, Struct[{
    source => Pattern[/puppet:\/\/\//]
  }]]                      $es_templates            = {},

) {

  # Users of this profile should always allow this class to configure ES as a
  # data node.
  #
  if has_key($config, 'node.data') {
    fail("Do not specify node.data in ${module_name}")
  }

  unless length($volume_groups) == 1 {
    fail('You must specify one volume group for the data dir')
  }

  # Note that it is expected that the user has created a custom fact espv
  # points to the physical volume for the data node filesystem.
  #
  assert_type(Stdlib::Absolutepath, $facts['espv'])

  create_resources(firewall_multi, $firewall_multis)
  create_resources(lvm::volume_group, $volume_groups)

  include elasticsearch
  include profile::elasticsearch

  $cluster_name = $config['cluster.name']

  elasticsearch::instance { $cluster_name:
    config        => merge($config, {'node.data' => true}),
    datadir       => $datadir,
    init_defaults => $init_defaults,
    jvm_options   => $jvm_options,
  }
  Mount[$datadir] -> File[$datadir]

  create_resources(elasticsearch::template, $es_templates)
  create_resources(elasticsearch::plugin, $es_plugins)

  unless empty($curator_jobs) {
    package { 'elastic-curator':
      ensure => installed,
    }
    create_resources(cron, $curator_jobs)
  }

  Sysctl {
    before => Service["elasticsearch-instance-${cluster_name}"]
  }

  if $vm_swappiness {
    sysctl { 'vm.swappiness': value => $vm_swappiness }
  }

  if $vm_max_map_count {
    sysctl { 'vm.max_map_count': value => $vm_max_map_count }
  }
}

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
  Hash                     $es_plugins              = {},
  Array[Pattern[/^-/]]     $jvm_options             = [],
  Integer[0,1]             $vm_swappiness           = undef,
  Integer                  $vm_max_map_count        = undef,
  Hash                     $ilm_policies            = {},

  # ES templates.
  Hash[String, Struct[{
    source => Pattern[/puppet:\/\/\//]
  }]]                      $es_templates            = {},

) {

  # Users of this profile should always allow this class to configure ES as a
  # data node.
  #
  if 'node.roles' in $config {
    fail("Do not specify node.roles in ${module_name}")
  }

  unless length($volume_groups) == 1 {
    fail('You must specify one volume group for the data dir')
  }

  # Note that the user must provide the custom fact espv pointing to the
  # physical volume for the data node filesystem. The Azure one-node topology
  # publishes this as /dev/disk/azure/scsi1/lun0.
  #
  assert_type(Stdlib::Absolutepath, $facts['espv'])

  create_resources(firewall_multi, $firewall_multis)
  create_resources(lvm::volume_group, $volume_groups)

  include profile::elasticsearch

  class { 'elasticsearch':
    config      => merge($config, {'node.roles' => ['master', 'data', 'ingest']}),
    datadir     => $datadir,
    jvm_options => $jvm_options,
  }

  Mount[$datadir] -> File[$datadir]

  create_resources(elasticsearch::template, $es_templates)
  create_resources(elasticsearch::plugin, $es_plugins)
  create_resources(elasticsearch::ilm_policy, $ilm_policies)

  Sysctl {
    before => Service['elasticsearch']
  }

  if $vm_swappiness {
    sysctl { 'vm.swappiness': value => $vm_swappiness }
  }

  if $vm_max_map_count {
    sysctl { 'vm.max_map_count': value => $vm_max_map_count }
  }
}

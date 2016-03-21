class profile::redis (
  Hash $firewall_multis,
  Hash $volume_groups,
  Integer[30000] $uid,
  Integer[30000] $gid,
  Integer[0,1] $vm_overcommit_memory,
  Integer $net_core_somaxconn,
) {
  validate_absolute_path($::redispv)

  create_resources(firewall_multi, $firewall_multis)

  # Our redis has a separate filesystem for its work dir.

  include redis
  $workdir = $::redis::workdir

  # Manage the user and group to prevent random UID and
  # GID assignment by the RPM.

  group { 'redis':
    ensure => present,
    gid    => $gid,
  }
  user { 'redis':
    ensure     => present,
    uid        => $uid,
    gid        => $gid,
    home       => $workdir,
    comment    => 'Redis Server',
    shell      => '/sbin/nologin',
    managehome => false,
  }
  User['redis'] -> Package['redis']

  # We manage the work dir's file explicitly because the
  # Redis module does not do this.

  create_resources(lvm::volume_group, $volume_groups)
  file { $workdir:
    ensure => directory,
    owner  => 'redis',
    group  => 'redis',
    mode   => '0755',
  }
  Mount[$workdir] -> File[$workdir]

  include disable_transparent_hugepage
  Service['disable-transparent-hugepage']
  ->
  sysctl { 'vm.overcommit_memory': value => $vm_overcommit_memory }
  ->
  sysctl { 'net.core.somaxconn': value => $net_core_somaxconn }
  ->
  Service['redis']
}

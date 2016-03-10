class profile::redis (
  Hash $firewall_multis,
  Hash $volume_groups,
  String $workdir,
  String $maxmemory,
  Integer[30000] $uid,
  Integer[30000] $gid,
) {
  create_resources('firewall_multi', $firewall_multis)

  create_resources('lvm::volume_group', $volume_groups)
  file { $workdir:
    ensure => directory,
    owner  => 'redis',
    group  => 'redis',
    mode   => '0755',
  }
  Mount[$workdir] -> File[$workdir]

  class { 'redis':
    workdir   => $workdir,
    maxmemory => $maxmemory,
  }
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

  sysctl { 'vm.overcommit_memory': value => 1 }
}

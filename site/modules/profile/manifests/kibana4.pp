class profile::kibana4 (
  Hash $firewall_multis,
  Integer[30000] $uid,
  Integer[30000] $gid,
) {
  # Pass in an empty hash here if used in conjunction with
  # profile::nginx.
  create_resources(firewall_multi, $firewall_multis)

  # Manage the user and group to prevent random UID and
  # GID assignment by the RPM.

  group { 'kibana':
    ensure => present,
    gid    => $gid,
  }
  user { 'kibana':
    ensure     => present,
    uid        => $uid,
    gid        => $gid,
    home       => '/home/kibana',
    shell      => '/bin/bash',
    managehome => false,
  }

  include profile::jdk
  include kibana4
}

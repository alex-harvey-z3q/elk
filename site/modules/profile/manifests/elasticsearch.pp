
class profile::elasticsearch (
  Integer[30000] $uid,
  Integer[30000] $gid,
) {
  include profile::jdk

  # Manage the user and group to prevent random UID and
  # GID assignment by the RPM.

  group { 'elasticsearch':
    ensure => present,
    gid    => $gid,
  }
  user { 'elasticsearch':
    ensure     => present,
    uid        => $uid,
    gid        => $gid,
    home       => '/usr/share/elasticsearch',
    shell      => '/sbin/nologin',
    managehome => false,
  }
  include elasticsearch
  User['elasticsearch'] -> Package['elasticsearch']
}

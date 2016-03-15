class profile::logstash::user (
  Integer[30000] $uid,
  Integer[30000] $gid,
) {

  # We move this user and group into
  # their own class as they are
  # included in both the
  # profile::logstash::indexer and 
  # profile::logstash::shipper classes,
  # which in turn may both be included
  # on a single node.

  group { 'logstash':
    ensure => present,
    gid    => $gid,
  }
  user { 'logstash':
    ensure     => present,
    uid        => $uid,
    gid        => $gid,
    comment    => 'logstash',
    home       => '/opt/logstash',
    shell      => '/sbin/nologin',
    managehome => false,
  }
}

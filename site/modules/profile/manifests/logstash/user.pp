class profile::logstash::user (
  Integer[30000] $uid,
  Integer[30000] $gid,
) {
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

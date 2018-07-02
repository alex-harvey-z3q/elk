class profile::logstash (
  Integer[30000] $uid,
  Integer[30000] $gid,

  Hash[String, Hash] $firewall_multis,

  Hash[String, Struct[{
    source => Pattern[/puppet:\/\/\//],
    path   => Stdlib::Absolutepath
  }]] $configfiles,

  Hash[String, Struct[{
    source => Pattern[/puppet:\/\/\//],
    path   => Stdlib::Absolutepath
  }]] $patternfiles,
) {
  create_resources(firewall_multi, $firewall_multis)

  # Manage the user and group to prevent random UID and
  # GID assignment by the RPM.
  #
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
  User['logstash'] -> Package['logstash']

  include logstash

  create_resources(logstash::configfile, $configfiles)
  create_resources(logstash::patternfile, $patternfiles)

  include profile::jdk
  Package[$profile::jdk::package] -> Package['logstash']
}

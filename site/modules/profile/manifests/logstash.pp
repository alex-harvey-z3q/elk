class profile::logstash (
  Integer[30000] $uid,
  Integer[30000] $gid,
  Hash $firewall_multis,
  Boolean $manage_repo,
  Array $jvm_options,
  Hash $configfiles,
  Hash $patternfiles,
  Array $pipelines, # TODO. Declare this as Array of Hashes.
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

  class { 'logstash':
    manage_repo => $manage_repo,
    jvm_options => $jvm_options,
    pipelines   => $pipelines,
  }

  create_resources(logstash::configfile, $configfiles)
  create_resources(logstash::patternfile, $patternfiles)

  include profile::jdk
  Package[$profile::jdk::package] -> Package['logstash']
}

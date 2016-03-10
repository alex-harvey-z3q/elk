class profile::logstash::indexer (
  Hash $firewall_multis,
  Hash $configfiles,
  String $sysconfig,
) {
  # FIXME: discussions underway with author of logstash
  # module to support running shipper and indexer on the
  # same node.

  # https://github.com/elastic/puppet-logstash/issues/144

  # For now, we need to manage configuration and service
  # ourselves.

  create_resources('firewall_multi', $firewall_multis)

  include logstash
  include profile::logstash::user
  User['logstash'] -> Package['logstash']

  include profile::jdk
  Package[$profile::jdk::package] -> Package['logstash']

  $dirs = [
    '/etc/logstash/logstash-indexer',
    '/etc/logstash/logstash-indexer/conf.d',
    '/etc/logstash/logstash-indexer/patterns',
    '/var/lib/logstash/logstash-indexer',
  ]
  file { $dirs:
    ensure  => directory,
    owner   => 'logstash',
    group   => 'logstash',
    mode    => '0755',
    require => Class[Logstash],
  }

  file { '/etc/sysconfig/logstash-indexer':
    ensure  => file,
    content => $sysconfig,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    notify  => Service['logstash-indexer'],
  }

  file { '/etc/init.d/logstash-indexer':
    ensure  => file,
    source  => 'puppet:///modules/site/lsnode/init.d/logstash-indexer',
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    notify  => Service['logstash-indexer'],
  }

  # FIXME: we wish we could use the logstash module's 
  # configfile defined type here, see comment above.

  $defaults = {
    ensure => file,
    owner  => 'logstash',
    group  => 'logstash',
    mode   => '0664',
    notify => Service['logstash-indexer'],
  }
  create_resources('file', $configfiles, $defaults)

  service { 'logstash-indexer':
    ensure    => running,
    enable    => true,
    hasstatus => true,
  }
}

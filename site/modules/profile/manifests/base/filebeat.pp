class profile::base::filebeat (
  Array[Stdlib::Absolutepath] $paths,
  Array[String[1]]            $output_hosts   = ['localhost:5044'],
  String[1]                   $package_ensure = 'present',
) {
  package { 'filebeat':
    ensure => $package_ensure,
  }

  file { '/etc/filebeat':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { '/etc/filebeat/inputs.d':
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => File['/etc/filebeat'],
  }

  file { '/etc/filebeat/filebeat.yml':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('profile/filebeat.yml.epp', {'output_hosts' => $output_hosts}),
    require => Package['filebeat'],
    notify  => Service['filebeat'],
  }

  file { '/etc/filebeat/inputs.d/syslogs.yml':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('profile/filebeat-input.yml.epp', {'paths' => $paths}),
    require => File['/etc/filebeat/inputs.d'],
    notify  => Service['filebeat'],
  }

  service { 'filebeat':
    ensure    => running,
    enable    => true,
    subscribe => Package['filebeat'],
  }
}

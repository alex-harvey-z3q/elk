class profile::base::filebeat (
  Boolean $manage_repo,
  String $package_ensure,
  Enum['5','6'] $major_version,
  Hash $outputs,
  Array $paths,
) {
  class { 'filebeat':
    package_ensure => $package_ensure,
    manage_repo    => $manage_repo,
    major_version  => $major_version,
    outputs        => $outputs,
  }
  filebeat::prospector { 'syslogs':
    paths => $paths,
    doc_type => 'syslog-beat',
  }
}

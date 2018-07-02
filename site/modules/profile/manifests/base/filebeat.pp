class profile::base::filebeat (
  Array[Stdlib::Absolutepath] $paths,
) {
  include filebeat

  filebeat::prospector { 'syslogs':
    paths => $paths,
    doc_type => 'syslog-beat',
  }
}

class profile::base::filebeat (
  Array $paths,
) {
  include filebeat

  filebeat::prospector { 'syslogs':
    paths => $paths,
    doc_type => 'syslog-beat',
  }
}

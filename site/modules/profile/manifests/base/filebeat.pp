class profile::base::filebeat (
  Array[Stdlib::Absolutepath] $paths,
) {
  include filebeat

  filebeat::input { 'syslogs':
    paths    => $paths,
    doc_type => 'syslog-beat',
  }
}

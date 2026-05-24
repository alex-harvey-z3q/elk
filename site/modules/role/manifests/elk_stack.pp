class role::elk_stack {
  include profile::base
  include profile::elasticsearch::data_node
  include profile::kibana
  include profile::nginx
  include profile::logstash

  Class['elastic_stack::repo'] -> Class['profile::elasticsearch::data_node']
  Class['elastic_stack::repo'] -> Class['profile::kibana']
  Class['elastic_stack::repo'] -> Class['profile::logstash']
  Class['elastic_stack::repo'] -> Class['profile::base::filebeat']

  Service['elasticsearch'] -> Service['kibana']
  Service['elasticsearch'] -> Service['logstash']
  Service['logstash'] -> Service['filebeat']
}

class role::elk_multi_node {
  include profile::base

  case $facts['elk_lab_role'] {
    'elasticsearch': {
      include profile::elasticsearch::data_node

      Class['elastic_stack::repo'] -> Class['profile::elasticsearch::data_node']
    }
    'logstash': {
      include profile::logstash

      Class['elastic_stack::repo'] -> Class['profile::logstash']
      Service['logstash'] -> Service['filebeat']
    }
    'kibana': {
      include profile::kibana

      Class['elastic_stack::repo'] -> Class['profile::kibana']
    }
    'edge': {
      include profile::nginx
    }
    default: {
      fail("Unsupported elk_lab_role '${facts['elk_lab_role']}' for role::elk_multi_node")
    }
  }

  Class['elastic_stack::repo'] -> Class['profile::base::filebeat']
}

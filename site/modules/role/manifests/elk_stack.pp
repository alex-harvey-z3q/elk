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

  elasticsearch::template { 'lab-defaults':
    content => {
      'index_patterns' => ['*'],
      'settings' => {
        'index' => {
          'number_of_replicas' => '0',
        },
      }
    },
  }

  Elasticsearch::Template['lab-defaults'] -> Service['logstash']
}

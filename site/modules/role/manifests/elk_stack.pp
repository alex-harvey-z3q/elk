class role::elk_stack {
  include profile::base
  include profile::logstash::shipper
  include profile::redis
  include profile::logstash::indexer
  include profile::elasticsearch::data_node
  include profile::elasticsearch::client_node
  include profile::kibana
  include profile::nginx

  # In a single node configuration with ES master and client instances, the
  # first to start will take port 9000.  Similarly, Kibana4 isn't happy unless
  # the ES cluster has started first.  Each ES instances takes less than 10
  # seconds to start.

  exec { [
    'wait-for-es-master',
    'wait-for-es-client',
    'wait-for-kibana',
  ]:
    path        => '/bin',
    command     => 'sleep 15',
    refreshonly => true,
  }

  # We also need to manually set number_of_replicas to 0 if running Kibana 4 on
  # a single-node ES cluster.  As before, we need to wait 10 seconds for Kibana
  # to start and insert its replica before we can tune the replica settings.

  # https://discuss.elastic.co/t/unassigned-shard-after-kibana-4-joins-cluster/39962/4

  exec { 'set-kibana-index-replicas-to-zero':
    path      => '/usr/bin',
    command   => "curl -XPUT 'localhost:9200/.kibana/_settings' -d '{\"index\":{\"number_of_replicas\":0}}' 2>/dev/null",
    logoutput => true,
    unless    => "curl 'localhost:9200/.kibana/_settings?pretty' 2>/dev/null | grep -q number_of_replicas.*0",
  }

  $cluster_name = $::profile::elasticsearch::data_node::config['cluster.name']

  Service["elasticsearch-instance-${cluster_name}"]
  ~>
  Exec['wait-for-es-master']
  ->
  Service["elasticsearch-instance-${cluster_name}-client-instance"]
  ~>
  Exec['wait-for-es-client']
  ->
  Service['kibana']
  ~>
  Exec['wait-for-kibana']
  ->
  Exec['set-kibana-index-replicas-to-zero']
}

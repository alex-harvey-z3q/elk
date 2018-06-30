class role::elk_stack {
  include profile::base
  include profile::elasticsearch::data_node
  include profile::elasticsearch::client_node
  include profile::kibana
  include profile::nginx
  include profile::redis
  include profile::logstash

  # The disable_transparent_hugepage module, included by the Redis profile,
  # runs a script that resets the value of vm.swappiness, breaking idempotence.
  # So the enable-tuned-profile has run before the swappiness setting is
  # enabled.
  #
  Exec['enable-tuned-profile']
  ->
  Sysctl['vm.swappiness']

  # I am not at this point sure why, but it seems that the Logstash service can
  # take quite a while to start. To avoid Beaker tests failing due to a
  # slow-starting Logstash service, this wait_for pauses the Puppet run until
  # the Logstash service actually started.
  #
  Wait_for {
    polling_frequency => 5,  # Wait up to 2 minutes.
    max_retries       => 24,
    refreshonly       => true,
  }

  wait_for { 'logstash':
    query => 'cat /var/log/logstash/logstash-plain.log 2> /dev/null',
    regex => 'Successfully started Logstash API endpoint',
  }

  Service['logstash']
  ~>
  Wait_for['logstash']

  # In a single node configuration with ES master and client instances, the
  # first to start will take port 9000.  Similarly, Kibana4 isn't happy unless
  # the ES cluster has started first. So we need to ensure that the master ES
  # starts before the client.

  wait_for { 'es-master':
    query => 'cat /var/log/elasticsearch/es01/es01.log 2> /dev/null',
    regex => 'o.e.n.Node.*started',
  }

  wait_for { 'es-client':
    query => 'cat /var/log/elasticsearch/es01-client-instance/es01.log 2> /dev/null',
    regex => 'o.e.n.Node.*started',
  }

  $cluster_name = $::profile::elasticsearch::data_node::config['cluster.name']

  Service["elasticsearch-instance-${cluster_name}"]
  ~>
  Wait_for['es-master']
  ->
  Service["elasticsearch-instance-${cluster_name}-client-instance"]
  ~>
  Wait_for['es-client']
  ->
  Service['kibana']
#  ~>
#  Wait_for['kibana']
#  ->
#  Wait_for['set-kibana-index-replicas-to-zero']

  # This seems to be the best way to set index.number_of_replicas to 0 for
  # all indices, as required in an all-in-one configuration.
  #
  elasticsearch::template { 'zero_replicas':
    content => {
      'index_patterns' => ['*'],
      'settings' => {
        'index.number_of_replicas' => '0'
      }
    },
  }

  # We also need to manually set number_of_replicas to 0 if running Kibana 4 on
  # a single-node ES cluster.  As before, we need to wait 10 seconds for Kibana
  # to start and insert its replica before we can tune the replica settings.

  # https://discuss.elastic.co/t/unassigned-shard-after-kibana-4-joins-cluster/39962/4

#  exec { 'set-kibana-index-replicas-to-zero':
#    path      => '/usr/bin',
#    command   => "curl -XPUT '0.0.0.0:9200/.kibana/_settings' -d '{\"index\":{\"number_of_replicas\":0}}' 2>/dev/null",
#    logoutput => true,
#    unless    => "curl '0.0.0.0:9200/.kibana/_settings?pretty' 2>/dev/null | grep -q number_of_replicas.*0",
#  }
}

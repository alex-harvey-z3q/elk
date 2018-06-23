class role::elk_stack {
  include profile::base
  include profile::elasticsearch::data_node
#  include profile::elasticsearch::client_node
#  include profile::kibana
#  include profile::nginx
  include profile::redis
  include profile::logstash

  # I am not at this point sure why, but it seems that the Logstash service can
  # take quite a while to start. To avoid Beaker tests failing due to a
  # slow-starting Logstash service, this wait_for pauses the Puppet run until
  # the Logstash service actually started.
  #
  wait_for { 'logstash':
    query             => 'cat /var/log/logstash/logstash-plain.log 2> /dev/null',
    regex             => 'Successfully started Logstash API endpoint',
    polling_frequency => 5,  # Wait up to 2 minutes.
    max_retries       => 24,
  }

  Service['logstash']
  ~>
  Wait_for['logstash']

  # The disable_transparent_hugepage module, included by the Redis profile,
  # runs a script that resets the value of vm.swappiness, breaking idempotence.
  #
  Exec['enable-tuned-profile']
  ->
  Sysctl['vm.swappiness']

  # In a single node configuration with ES master and client instances, the
  # first to start will take port 9000.  Similarly, Kibana4 isn't happy unless
  # the ES cluster has started first.  Each ES instances takes less than 10
  # seconds to start.

#  wait_for { ['es-master', 'es-client',
#    #    'wait-for-kibana',
#  ]:
#  }

  # We also need to manually set number_of_replicas to 0 if running Kibana 4 on
  # a single-node ES cluster.  As before, we need to wait 10 seconds for Kibana
  # to start and insert its replica before we can tune the replica settings.

  # https://discuss.elastic.co/t/unassigned-shard-after-kibana-4-joins-cluster/39962/4

#  exec { 'set-kibana-index-replicas-to-zero':
#    path      => '/usr/bin',
#    command   => "curl -XPUT 'localhost:9200/.kibana/_settings' -d '{\"index\":{\"number_of_replicas\":0}}' 2>/dev/null",
#    logoutput => true,
#    unless    => "curl 'localhost:9200/.kibana/_settings?pretty' 2>/dev/null | grep -q number_of_replicas.*0",
#  }
#
#  $cluster_name = $::profile::elasticsearch::data_node::config['cluster.name']
#
#  Service["elasticsearch-instance-${cluster_name}"]
#  ~>
#  Wait_for['es-master']
#  ->
#  Service["elasticsearch-instance-${cluster_name}-client-instance"]
#  ~>
#  Wait_for['es-client']
#  ->
#  Service['kibana']
#  ~>
#  Wait_for['kibana']
#  ->
#  Wait_for['set-kibana-index-replicas-to-zero']
}

# Rules which are applied to all nodes before any others.
class profile::base::firewall::pre {
  Firewall {
    require => undef,
  }
  firewall { '00000 accept all icmp':
    proto   => 'icmp',
    action  => 'accept',
  }->
  firewall { '00001 accept all to lo interface':
    proto   => 'all',
    iniface => 'lo',
    action  => 'accept',
  }->
  firewall { '00002 accept related established rules':
    proto   => 'all',
    state   => ['RELATED', 'ESTABLISHED'],
    action  => 'accept',
  }
}

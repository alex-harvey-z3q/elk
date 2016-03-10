# Rules which are applied to all nodes AFTER any others.
class profile::base::firewall::post () {
  firewall { '99998 log packet drops':
    jump       => 'LOG',
    proto      => 'all',
    log_prefix => 'iptables InDrop: ',
    log_level  => 'warn',
  }->
  firewall { '99999 drop all':
    proto   => 'all',
    action  => 'drop',
    before  =>  undef
  }
}

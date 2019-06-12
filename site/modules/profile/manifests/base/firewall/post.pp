# Rules which are applied to all nodes AFTER any others.
class profile::base::firewall::post () {
  firewall { '999 drop all':
    proto  => 'all',
    action => 'drop',
    before => undef,
  }
}

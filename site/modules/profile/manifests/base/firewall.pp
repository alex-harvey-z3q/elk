class profile::base::firewall {
  include firewall

  include profile::base::firewall::pre
  include profile::base::firewall::post

  firewallchain { 'INPUT:filter:IPv4':
    ensure => present,
    purge => true,
  }
}

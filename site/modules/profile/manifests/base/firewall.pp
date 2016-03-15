class profile::base::firewall {
  include firewall

  include profile::base::firewall::pre
  include profile::base::firewall::post

  resources { 'firewall':
    purge => true,
  }
}

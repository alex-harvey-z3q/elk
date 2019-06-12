class profile::base::firewall {
  resources { 'firewall':
    purge => true,
  }

  include profile::base::firewall::pre
  include profile::base::firewall::post

  include firewall
}

class profile::base::firewall {
  class { ['profile::base::firewall::pre',
           'profile::base::firewall::post',
          ]:
  } ->
  resources { 'firewall':
    purge => true,
  }
}

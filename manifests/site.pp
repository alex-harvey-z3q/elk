stage { 'pre': before => Stage['main'] }

Firewall {
  require => Class['profile::base::firewall::pre'],
  before  => Class['profile::base::firewall::post'],
}

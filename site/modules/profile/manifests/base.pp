class profile::base (
  Hash $firewall_multis,
) {
  create_resources(firewall_multi, $firewall_multis)
  include profile::base::firewall
  include profile::base::yum
  include ntp
  include profile::base::filebeat
  #  include profile::base::logrotate
}

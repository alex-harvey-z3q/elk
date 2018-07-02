class profile::base (
  Hash[String, Hash] $firewall_multis,
  Hash[String, Hash] $tools,
) {
  create_resources(firewall_multi, $firewall_multis)
  create_resources(package, $tools)

  include profile::base::firewall
  include profile::base::yum
  include ntp
  include profile::base::filebeat
  #  include profile::base::logrotate
}

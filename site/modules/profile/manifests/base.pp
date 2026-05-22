class profile::base (
  Hash[String, Hash] $firewall_multis,
  Hash[String, Hash] $tools,
) {
  create_resources(firewall_multi, $firewall_multis)
  create_resources(package, $tools)

  include elastic_stack::repo
  include profile::base::firewall
  include profile::base::yum
  include profile::base::filebeat
}

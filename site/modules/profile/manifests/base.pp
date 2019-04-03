# @summary Base profile
#
# @abstract The base profile that configures adds the Elastic Filebeat
#   agent, and also an iptables firewall, yum repos both for the ELK
#   and Linux, NTP and other services.
#
# @param [Hash[String, Hash]] firewall_multis A Hash of firewall rules.
# @param [Hash[String, Hash]] tools A Hash of external tools as package
#   resources.
#
# @example Declare this class and read inputs from Hiera
#
#   include profile::base
#
# @example Open port 22 and 80 in a Hiera block
#
#   profile::base::firewall_multis:
#    '00099 accept tcp ports for SSH and Kibana':
#      dport: [22, 80]
#      action: accept
#      proto: tcp
#      source:
#        - 0.0.0.0/0
#
# @example Install vim
#
#   profile::base::tools:
#     vim:
#       ensure: installed
#
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

class profile::base {
#  class { 'yum':
#    stage => pre,
#  }
  include ntp
  include profile::base::firewall
  #  include profile::base::logrotate
  #  include profile::base::filebeat
}

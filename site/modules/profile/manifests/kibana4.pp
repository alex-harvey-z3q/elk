class profile::kibana4 (
  Hash $firewall_multis,
  String $package_download_url,
  Integer[30000] $uid,
  Integer[30000] $gid,
  Hash $config,
) {
  # Pass in an empty hash here if used in conjunction with
  # profile::nginx.
  create_resources(firewall_multi, $firewall_multis)

  include profile::jdk

  class { 'kibana4':
    package_provider     => 'archive',
    archive_provider     => 'camptocamp',
    package_download_url => $package_download_url,
    package_dl_timeout   => 0,
    manage_user          => true,
    manage_init_file     => true,
    service_name         => 'kibana',
    kibana4_user         => 'kibana',
    kibana4_group        => 'kibana',
    kibana4_uid          => $uid,
    kibana4_gid          => $gid,
    config               => $config,
  }
}

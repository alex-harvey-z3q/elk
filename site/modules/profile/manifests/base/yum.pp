class profile::base::yum (
  Hash $repos,
) {
  Yumrepo {
    stage => 'pre',
  }
  file { '/etc/yum.repos.d/':
    ensure  => directory,
    recurse => true,
    purge   => true,
  }
  create_resources(yumrepo, $repos)
  keys($repos).each |String $yumrepo| {
    file { "/etc/yum.repos.d/${yumrepo}.repo": }
    ->
    Yumrepo[$yumrepo]
  }
}

class profile::base::yum (
  Hash $repos,
) {
  Yumrepo {
    stage => 'pre',
  }
  create_resources(yumrepo, $repos)

  # Since we must purge the file resources in
  # /etc/yum.repos.d/, we must also declare the 
  # associated files to prevent them also
  # being purged.

  keys($repos).each |String $yumrepo| {
    file { "/etc/yum.repos.d/${yumrepo}.repo": }
    ->
    Yumrepo[$yumrepo]
  }
  file { '/etc/yum.repos.d/':
    ensure  => directory,
    recurse => true,
    purge   => true,
  }
}

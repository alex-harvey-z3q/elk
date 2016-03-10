class profile::jdk (
  String $package,
) {
  package { $package:
    ensure => installed,
  }
}

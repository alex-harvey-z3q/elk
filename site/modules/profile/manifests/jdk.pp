class profile::jdk (
  String[1] $package,
) {
  package { $package:
    ensure => installed,
  }
}

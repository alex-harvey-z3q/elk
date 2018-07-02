class profile::jdk (
  Pattern[/java-\d+\.\d+\.\d+-openjdk/] $package, #/ # comment tricks vim highlighting.
) {
  package { $package:
    ensure => installed,
  }
}

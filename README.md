# elk

## Status

This is still a work-in-progress, but might serve as a useful introduction to the design of an ELK roles and profiles solution in Puppet.

## Elasticsearch

### elasticsearch class

The elasticsearch class is declared as:

~~~ puppet
class { 'elasticsearch':
  api_host    => '0.0.0.0',
  api_timeout => 120,
  manage_repo => false,
}
~~~

This is global for both a data and client node.

### data node

#### elasticsearch::instance class

On a data node, the elasticsearch::instance class is declared as:

~~~ puppet
elasticsearch::instance { 'es01':
  datadir       => '/srv/es',
  config        => {
    'cluster.name' => 'es01',
    'node.name'    => "es01_${facts['hostname']}",
    'node.master'  => true,
    'node.data'    => true,
  },
  init_defaults => {
    JAVA_HOME => '/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.171-8.b10.el7_5.x86_64',
  },
  jvm_options   => ['-Xms1g', '-Xmx1g' ],
}
~~~

#### elasticsearch template

We use the following index template:

~~~ json
{
  "aliases": {},
  "index_patterns": [
    "logstash-*"
  ],
  "mappings": {
    "_default_": {
      "dynamic_templates": [
        {
          "string_fields": {
            "mapping": {
              "fields": {
                "raw": {
                  "ignore_above": "256",
                  "index": "not_analyzed",
                  "type": "text"
                }
              },
              "index": "analyzed",
              "omit_norms": "true",
              "type": "text"
            },
            "match": "*",
            "match_mapping_type": "string"
          }
        }
      ],
      "properties": {
        "@version": {
          "index": "false",
          "type": "text"
        },
        "geoip": {
          "dynamic": "true",
          "properties": {
            "location": {
              "type": "geo_point"
            }
          },
          "type": "object"
        }
      }
    }
  },
  "order": "0",
  "settings": {
    "index": {
      "refresh_interval": "5s"
    }
  }
}
~~~

## Testing

### Dependencies

Make sure you have:

* Ruby Gems
* bundler
* RVM
* Squid Man

### Squid Man set up

Configure Squid Man to listen on port 3128 and cache all.

### Run the tests

Install the necessary gems:

~~~ text
bundle install
~~~

To run the unit tests from the root of the source code:

~~~ text
bundle exec rake librarian_spec
~~~

To run the acceptance tests:

~~~ text
ipaddr=$(ifconfig en0 | awk '/inet/ {print $2}')
export BEAKER_PACKAGE_PROXY=http://${ipaddr}:3128/
~~~

Puppet 5.5.1:

~~~ text
export BEAKER_PUPPET_COLLECTION=puppet5
export BEAKER_PUPPET_INSTALL_VERSION=5.5.1
~~~

Puppet 4.10.11:

~~~ text
export BEAKER_PUPPET_COLLECTION=pc1
export BEAKER_PUPPET_INSTALL_VERSION=1.10.12
~~~

Then:

~~~ text
bundle exec rspec spec/acceptance
~~~

Tested using Puppet 4.10.11, 5.5.1 and Ruby 2.4.1.

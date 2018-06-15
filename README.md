# elk

## Status

This is still a work-in-progress, but might serve as a useful introduction to the design of an ELK roles and profiles solution in Puppet.

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
export BEAKER_PACKAGE_PROXY=http://<laptop_ip>:3128/
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

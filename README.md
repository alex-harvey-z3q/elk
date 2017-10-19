# elk

## Status

This is still a work-in-progress, but might serve as a useful introduction to the design of an ELK roles and profiles solution in Puppet.

## Testing

Make sure you have:

* rake
* bundler

Install the necessary gems:

    bundle install

To run the tests from the root of the source code:

    bundle exec rake spec

To run the acceptance tests:

    BEAKER_set=centos-72-x64 bundle exec rspec spec/acceptance

Tested using Ruby 2.4.1.

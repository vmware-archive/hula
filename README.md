# Hula

Hula is ruby client that provides two libraries wrapping the CF and BOSH cli.

It gives a way to programmatically manage your bosh manifest and bosh deployments with
`BoshDirector` and `BoshManifest`.
Similarly with CF, you can make use of the `CloudFoundry` class to call common
CF CLI operations.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'hula'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install hula

## Usage

### CloudFoundry

A simple scenario of pushing a cf application and binding a service using `Hula::CloudFoundry`

1. Instantiate a Cloudfoundry instance with correct args (domain, api_url etc..).
1. Authenticate using the `login` method.
1. Assuming an org/space, target your org and space using the `target_org` and `target_space` method respectively.
1. Push your app with `push_app`.
1. Assuming an already enabled service, use the `bind_app_to_service` method.
1. Start your app with `start_app`.

```ruby
cf = Hula::CloudFoundry.new(domain: 'my.cf.com', api_url: 'api.my.cf.com')
cf.login('admin', 'admin')
cf.target_org('org')
cf.target_space('space')
cf.push_app('./my-app', 'my-app')
cf.bind_app_to_service('my-app', 'my-service')
```

### Bosh

You can use `Hula::BoshDirector` to deploy, run errands, get ips from jobs and more:

1. Instantiate Hula::Bosh with your director information.
1. Use `deploy` with a valid manifest to deploy it.
1. Use `run_errand` to run the given errand specified in the manifest.
1. Use `ips_for_job` to get all ips for a given job in the manifest.

```ruby
bosh = Hula::BoshDirector(target_url: 'bosh_director_url', username: 'user',password: 'pass')
bosh.deploy('./manifests/manifest.yml')
bosh.run_errand('some_errand_name')
puts bosh.ips_for_job('job_name')
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/hula/fork )
1. Create your feature branch (`git checkout -b my-new-feature`)
1. Add tests to your feature
1. Commit your changes (`git commit -am 'Add some feature'`)
1. Push to the branch (`git push origin my-new-feature`)
1. Create a new Pull Request

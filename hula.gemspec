# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'hula/version'

Gem::Specification.new do |spec|
  spec.name          = 'hula'
  spec.version       = Hula::VERSION
  spec.authors       = ['Will Pragnell']
  spec.email         = ['wpragnell@pivotal.io']
  spec.licenses      = ['Copyright (c) Pivotal Software, Inc.']
  spec.summary       = 'A tasty wrapper around cf, and more...'
  spec.description   = 'We were using cf and bosh command line clients in a lot of places, mostly specs, this should put an end to the crazy shell-ing'
  spec.homepage      = 'https://github.com/pivotal-cf-experimental/hula'
  spec.license       = 'proprietary'

  spec.required_ruby_version  = '>= 2.1'

  spec.files         = Dir.glob('lib/**/*') + ['LEGAL']
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'gem-release', '~> 0.7.3'
  spec.add_development_dependency 'gemfury', '~> 0.4'
  spec.add_development_dependency 'guard-rspec', '~> 4.3'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.1'
  spec.add_development_dependency 'rspec_junit_formatter', '~> 0.2'
  spec.add_development_dependency 'terminal-notifier-guard', '~> 1.6'
  spec.add_development_dependency 'webmock', '~> 1.18'

  # For http_proxy_upstream_socks specs
  spec.add_development_dependency 'rack', '~> 1.6'
  spec.add_development_dependency 'proxymachine', '~> 1.2'
  spec.add_development_dependency 'sys-proctable', '~> 0.9'
end

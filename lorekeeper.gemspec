# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'lorekeeper/version'

Gem::Specification.new do |spec|
  spec.name          = 'lorekeeper'
  spec.version       = Lorekeeper::VERSION
  spec.authors       = ['Jordi Polo']
  spec.email         = ['mumismo@gmail.com']

  spec.summary       = 'Very fast JSON logger'
  spec.description   = 'Opinionated logger which outputs messages in JSON format'
  spec.homepage      = 'https://github.com/JordiPolo/lorekeeper'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.7.0'

  spec.add_dependency 'oj', '>= 3.12', '< 4.0'

  spec.add_development_dependency 'activesupport', '>= 4.0'
  spec.add_development_dependency 'bundler', '>= 1.16', '< 3.0'
  spec.add_development_dependency 'rake', '~> 12.0'
  spec.add_development_dependency 'rspec', '~> 3.8'
  spec.add_development_dependency 'benchmark-ips', '~> 2.3'
  spec.add_development_dependency 'timecop', '~> 0.8'
  spec.add_development_dependency 'byebug', '~> 11.0'
  spec.add_development_dependency 'rbtrace', '~> 0.4'
  spec.add_development_dependency 'simplecov', '~> 0.16'
  spec.add_development_dependency 'mutant-rspec', '~> 0.8'
  spec.add_development_dependency 'rubocop-mdsol', '~> 0.3'
end

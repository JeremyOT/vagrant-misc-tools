# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'vagrant-simple-sync/version'

Gem::Specification.new do |spec|
  spec.name          = "vagrant-simple-sync"
  spec.version       = VagrantPlugins::SimpleSync::VERSION
  spec.authors       = ["JeremyOT"]
  spec.email         = ["jeremy@simple-sync.io"]
  spec.description   = %q{Support SIMPLE_SYNC addons}
  spec.summary       = %q{Support SIMPLE_SYNC addons}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end

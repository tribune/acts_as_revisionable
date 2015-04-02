# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'acts_as_revisionable/version'
Gem::Specification.new do |spec|
  spec.name          = "acts_as_revisionable"
  spec.version       = ActsAsRevisionable::VERSION
  spec.authors       = ["Brian Durand"]
  spec.email         = ["brian@embellishedvisions.com"]
  spec.summary       = %Q{ActiveRecord extension that provides revision support so that history can be tracked and changes can be reverted.}
  spec.description   = %Q(ActiveRecord extension that provides revision support so that history can be tracked and changes can be reverted. Emphasis for this plugin versus similar ones is including associations, saving on storage, and extensibility of the model.)
  spec.homepage      = ""
 
  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency('activerecord', '>= 3.1.0', '< 4.3.0')

  spec.add_development_dependency('appraisal')
  spec.add_development_dependency('byebug')

  # We need to avoid CPK < 3.1.7 because those use '>=' instead of '~>' for AR dep,
  # which may cause an obsolete CPK to be used with a newer AR.
  spec.add_development_dependency('composite_primary_keys', '>= 3.1.7')
  spec.add_development_dependency('sqlite3')
  spec.add_development_dependency('rspec', '~> 2.0')
 
  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end

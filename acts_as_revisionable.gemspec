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

  # Should be set only when testing. You may need to delete Gemfile.lock.
  activerec_ver_spec = ENV['ACTS_AS_REVISIONABLE_AR_VER']
  if activerec_ver_spec
    spec.add_dependency('activerecord', activerec_ver_spec)
  else
    spec.add_dependency('activerecord', '>= 3.0.20', '< 4.0')
  end

  # Don't restrict CPK version - let Bundler pick the correct one
  spec.add_development_dependency('composite_primary_keys')
  spec.add_development_dependency('sqlite3')
  spec.add_development_dependency('rspec', '~> 2.0')
 
  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end

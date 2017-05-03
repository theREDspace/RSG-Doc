#********** Copyright 2017 REDspace. All Rights Reserved. **********
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rsg_doc'

Gem::Specification.new do |s|
  s.name          = 'rsg_doc'
  s.version       = RSGDoc::VERSION
  s.summary       = "Generates documentation for Brightscript referenced in Scenegraph markup"
  s.description   = ""
  s.authors       = ["TyRud"]
  s.email         = 'tyler.rudolph@redspace.com'
  s.files         = `git ls-files -z`.split("\x0")
  s.homepage      = "https://rubygems.org/gems/example"
  s.license       = 'Apache-2.0'

  s.bindir        = ["bin"]
  s.executables   = ["rsg"]

  s.required_ruby_version = "~> 2.3"

  s.add_development_dependency "byebug", "~> 9.0"
end
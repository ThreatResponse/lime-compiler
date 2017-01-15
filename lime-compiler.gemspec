# -*- encoding: utf-8 -*-
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "lime-compiler/version"

Gem::Specification.new do |gem|
  gem.authors               = ["Joel Ferrier"]
  gem.email                 = ["joel@ferrier.io"]
  gem.version               = LimeCompiler::VERSION
  gem.required_ruby_version = '>= 2.0.0'
  gem.description           = %q{A ruby wrapper for docker and LiME}
  gem.summary               = %q{Builds LiME kernel modules with docker}
  gem.homepage              = "https://github.com/ThreatResponse/lime-compiler"

  gem.files                 = `git ls-files -z`.split("\x0")
  gem.executables           << 'lime-compiler'
  gem.executables           << 'gpg-setup'
  gem.name                  = "lime-compiler"
  gem.require_paths         = ["lib"]
  gem.licenses              = ["MIT"]
end

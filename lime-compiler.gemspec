# -*- encoding: utf-8 -*-
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "lime-compile/version"

Gem::Specification.new do |gem|
     gem.authors       = ["Joel Ferrier"]
     gem.email         = ["joel@ferrier.io"]
     gem.version       = LimeCompiler::VERSION
     gem.description   = %q{A ruby wrapper for docker and LiME}
     gem.summary       = %q{Builds LiME kernel modules with docker}
     gem.homepage      = ""

     gem.files         = `git ls-files -z`.split("\x0")
     gem.executables   = %q(lime-compiler)
     gem.name          = "lime-compiler"
     gem.require_paths = ["lib"]
     gem.licenses      = ["MIT"]
end

# Lime Compiler

## Running

    ./bin/lime-compiler -c /conf/config.yml

## Requirements

Ensure docker is installed and the user running `lime-compiler` can write to the docker socket

## Installation

Install from github:  

    gem install specific_install
    gem specific_install -l https://github.com/ThreatResponse/ruby-lime-compiler-private.git

Build and install locally:  

    gem build lime-compiler.gemspec
    gem install lime-compiler-0.0.1.gem

Gem installation places `lime-compiler` in the systems path


## TODO:

- document config structure
- implement logging
- test debian support

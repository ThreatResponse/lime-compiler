# Lime Compiler

## Usage

    Usage: lime-compiler [options]
        -h, --help                       Show this help message
        -c, --config config.yml          [Required] path to config file
        -m, --moduledir modules/         [Required] module output directory
        -a, --archive archive/           [Required] archive output directory
        -v, --[no-]verbose               Run verbosely

You can run straight from the repository, using the provided archive and modules directories

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

- support uploading to s3
- test suite
- document config structure
- parallel builds?
- sign kernel modules

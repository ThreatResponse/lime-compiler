# Lime Compiler

Builds LiME Kernel modules for:
- Centos 6
- Centos 7
- Debian 7
- Debian 8
- Ubuntu 12.04
- Ubuntu 14.04
- Ubuntu 15.10
- Ubuntu 16.04

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

## License

The MIT License (MIT)

Copyright (c) 2016 ThreatResponse

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

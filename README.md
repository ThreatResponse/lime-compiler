# Lime Compiler

Builds LiME Kernel modules for:
- Amazon Linux
- Centos 6
- Centos 7
- Debian 7
- Debian 8
- Ubuntu 12.04
- Ubuntu 14.04
- Ubuntu 15.10
- Ubuntu 16.04
- Ubuntu 16.10

## Usage

```
Usage: lime-compiler [options]
    -h, --help                       Show this help message
    -v, --version                    Print gem version
    -c, --config config.yml          [Required] path to config file
    -m, --moduledir modules/         [Required] module output directory
    -a, --archive archive/           [Required] archive output directory
        --build-all                  Rebuild existing lime modules in the build root
        --gpg-sign                   Sign compiled modules
        --sign-all                   Regenerate signatures for existing modules in build root
        --gpg-id identity            GPG id for module signing
        --gpg-no-verify              Bypass gpg signature checks
        --gpg-home path/to/gpghome   Custom gpg home directory
        --rm-gpg-home                Custom gpg home directory
        --kms-region region          AWS region for KMS client instantiation
        --s3-region region           AWS region for S3 client instantiation
        --aes-key-export export.aes  Path to aes key export created with gpg-setup
        --gpg-key-export export.aes  Path to encrypted gpg key created with gpg-setup
        --[no-]verbose               Run verbosely
```


You can run straight from the repository, using the provided archive and modules directories

## Requirements

Ensure docker is installed and the user running `lime-compiler` can write to the docker socket
GPG v2.1 or higher is required for signing modules with a passphrase protected GPG key

## Installation

Install from github:  

    gem install specific_install
    gem specific_install -l https://github.com/ThreatResponse/lime-compiler.git

Build and install locally:  

    gem build lime-compiler.gemspec
    gem install lime-compiler-0.0.1.gem

Gem installation places `lime-compiler` in the systems path

## Prepare GPG Keys For Unattended Builds

To enable unattended builds with module signing the gpg key used for signing can be encrypted via kms and stored in an s3 bucket.

The `gpg-setup` executable included with the gem generates a kms data encryption key which is used to encrypted the specified gpg key.

Optionally a passphrase can be supplied for the gpg key being encrypted

Usage:

```
gpg-setup -h
gpg-setup: Encrypts GPG key for storage
    -h, --help                       Show this help message
        --aws-region region          aws region
        --kms-id id                  kms key id
        --gpg-key-path path          path to gpg key
        --gpg-key-id fingerprint     gpg key fingerprint
        --gpg-key-passphrase pass    gpg key passphrase

```

Example Run:

```
gpg-setup --aws-region <aws-region> \
          --kms-id <kms-key-id> \
          --gpg-key-path <path/to/gpg.key> \
          --gpg-key-id <fingerprint> \
          --gpg-key-passphrase <passphrase>
Exported encrypted AES key and IV to aes_export.aes
Exported encrypted GPG key to gpg_export.aes
```

**Note:** The gpg being encrypted must already be exported from the user's keychain

**TODO:** Document IAM policy required for gpg-setup script

**TODO:** Document IAM policy required for lime-compiler builds

## Example

To generate kernel modules without gpg signatures and the provided configuration files see the following command.

    $ # ensure that the build and archive directories exist
    $ mkdir build archive
    $ lime-compiler --config conf/config.yml -m build/ -a archive/ --gpg-no-verify

## Build Output

Below is a truncated example of a build, note that files ending in .sig are only generate if the `--gpg-sign` flag is used in conjunction with `--gpg-id`.

    $ tree build/
    build/
    ├── modules
    │   ├── lime-4.4.0-21-generic.ko
    │   ├── lime-4.4.0-21-generic.ko.sig
    │   ├── lime-4.4.0-22-generic.ko
    │   └── lime-4.4.0-22-generic.ko.sig
    └── repodata
        ├── c5bff3ea30873b1dedd1aa333df23df9f0920be8cb4e515766e5ff3bd083633d-primary.xml.gz
        ├── repomd.xml
        └── repomd.xml.sig


## Docker Custimization

Docker's default disk size of 10 Gb is to small for installing all the required kernel headers for some older distributions.

The default disk size can be expanded by reconfiguring the docker daemon.  These instructions are lifted from the offical [docker docs](https://docs.docker.com/engine/admin/systemd/)

need to expand base images size beyond 20gb

### SystemD

Create a directory to hold partial unit files

```
$ mkdir -p /etc/systemd/system/docker.service.d
```

Create a partial unit file with the name `10-docker-environment.conf` in the `docker.service.d` directory.

```
$ cat /etc/systemd/system/docker.service.d/10-docker-environment.conf
[Service]
EnvironmentFile=-/etc/sysconfig/docker
EnvironmentFile=-/etc/sysconfig/docker-storage
EnvironmentFile=-/etc/sysconfig/docker-network

ExecStart=
ExecStart=/usr/bin/dockerd $OPTIONS \
$DOCKER_STORAGE_OPTIONS \
$DOCKER_NETWORK_OPTIONS \
$BLOCK_REGISTRY \
$INSECURE_REGISTRY

```

Create the files referenced in the `EnvironmentFile` directives.

```
$ touch /etc/sysconfig/docker
$ echo "DOCKER_STORAGE_OPTIONS= --storage-opt dm.basesize=20G" > /etc/sysconfig/docker-storage
$ touch /etc/sysconfig/docker-networking
```

Reload the docker service and restart the docker daemon

```
$ systemctl stop docker
$ systemctl daemon-reload
$ systemctl start docker
```

Verify the `Base Device Size` has been increased.

```
$ docker info | grep "Base Device Size"
  Base Device Size: 21.47 GB
```

Containers and their base images will have to be deleted for the new disk sizes to take affect

## TODO:

- support uploading to s3
- test suite
- document config structure

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

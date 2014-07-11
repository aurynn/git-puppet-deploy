#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

mkdir -p /var/deploy/init
cd /var/deploy/init

RELEASE=puppetlabs-release-`lsb_release -cs`

if [ ! dpkg-query -W $RELEASE ]; then
    if [ ! -f /var/deploy/init/puppetlabs-release-`lsb_release -cs`.deb ]; then
        wget https://apt.puppetlabs.com/puppetlabs-release-`lsb_release -cs`.deb
    fi
    dpkg -i /var/deploy/init/puppetlabs-release-`lsb_release -cs`.deb
    apt-get update
fi

# this will always be the puppetlabs version, now.
if [ ! dpkg-query -W puppet ]; then
    apt-get install -y puppet
fi

apt-get upgrade

FACTER_checkout_dir=$DIR puppet apply $DIR/bootstrap.pp

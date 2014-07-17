#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

mkdir -p /var/deploy/init
cd /var/deploy/init

RELEASE=puppetlabs-release-`lsb_release -cs`
dpkg-query -W $RELEASE 2> /dev/null

if [ ! $? ]; then
    if [ ! -f /var/deploy/init/puppetlabs-release-`lsb_release -cs`.deb ]; then
        wget https://apt.puppetlabs.com/puppetlabs-release-`lsb_release -cs`.deb
    fi
    dpkg -i /var/deploy/init/puppetlabs-release-`lsb_release -cs`.deb
    apt-get update
fi

# this will always be the puppetlabs version, now.

dpkg-query -W puppet 2> /dev/null
if [ ! $? ]; then
    echo "attempting to install Puppet"
    apt-get install -y puppet
fi

echo "Upgrading."
apt-get -y upgrade

FACTER_checkout_dir=$DIR puppet apply $DIR/bootstrap.pp

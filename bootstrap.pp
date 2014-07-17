# GIT-puppet-provision
# Sets up a server to be managed with puppet via a controlled git repository.
# This bootstrap is expected to be run by init.sh.
#

$deploy_base     = "/var/deploy"
$deploy_repo     = "/var/deploy/repo"
$deploy_checkout = "${deploy_base}/checkout"

# $checkout_dir is set by a puppet fact.

# Everything we're doing happens as the deploy user.
# Modify File and Exec types to that end.
File {
    owner => "deploy",
    group => "deploy"
}
Exec {
    path => "/bin:/usr/bin",
    user => "deploy"
}

# Set up our repo directories under deploy ownership

file {$deploy_base:
    ensure => directory
}

file {$deploy_repo:
    ensure => directory
}

file {$deploy_checkout:
    ensure => directory
}

# Install Git
package {"git":
    ensure => present
}

# Declare the deploy group and user

user {"deploy":
    managehome => "true",
    groups     => ["deploy"],
    home       => $deploy_base,
    shell      => "/usr/sbin/nologin"
}

file {"${deploy_base}/.ssh":
    ensure => directory,
    mode   => "0700"
}

file {"${deploy_base}/.ssh/authorized_keys":
    mode    => "0600",
    content => file("${checkout_dir}/deploy.rsa.pub")
}

group {"deploy":
    ensure => present
}

# Create the receiving git repository
exec{"git-init":
    command => "git init ${deploy_path}",
    creates => "${deploy_path}/.git",
}

# Branch it, checking out into an always-empty branch
exec {"git-branch":
    command => "git checkout -b empty",
    cwd     => $deploy_path
}

# Add our post-receive hook. This performs the on-push checkout and 
# puppet apply.

file {"post-receive":
    path   => "${deploy_path}/.git/hooks/post-receive",
    source => file("${::checkout_dir}/post-receive"),
    mode   => "0755"
}

# Give the deploy user puppet powers. but only puppet powers.
augeas {"deploy-sudoers":
    context => "/file/etc/sudoers",
    changes => [
        # allow wheel users to use sudo
        'set spec[user = "deploy"]/user deploy',
        'set spec[user = "deploy"]/host_group/host ALL',
        'set spec[user = "deploy"]/host_group/command puppet',
        'set spec[user = "deploy"]/host_group/command gem',
        'set spec[user = "deploy"]/host_group/command/runas_user root',
        'set spec[user = "deploy"]/host_group/command/tag NOPASSWD'
    ]
}

# Groups and users are required to do anything else.
# Uses file and exec selectors to declare that the users are needed for 
# everything.
Group["deploy"] -> User["deploy"] -> File <| |>
User["deploy"] -> Exec <| |>

Package["git"] -> Exec["git-init"]
Package["git"] -> Exec["git-branch"]

# git-branch will be notified when git-init happens.
# This should, therefore, only ever happen once.
Exec["git-init"] ~> Exec["git-branch"]

# We need the repo directory to exist before we init it.
File[$deploy_repo] -> Exec["git-init"]

User["deploy"] -> Augeas["deploy-sudoers"]

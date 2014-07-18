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
    shell      => "/bin/bash"
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
    command => "git init ${deploy_repo}",
    creates => "${deploy_repo}/.git",
}

# Branch it, checking out into an always-empty branch
exec {"git-branch-create":
    command => "git branch empty",
    cwd     => $deploy_repo,
    creates => "${deploy_repo}/.git/logs/refs/heads/empty"
}

exec {"git-branch-checkout":
    command => "git checkout empty",
    cwd     => $deploy_repo,
}

# Add our post-receive hook. This performs the on-push checkout and 
# puppet apply.

notice("${deploy_repo}/.git/hooks/post-receive")
notice("${::checkout_dir}/post-receive")

file {"post-receive":
    path    => "${deploy_repo}/.git/hooks/post-receive",
    content => file("${::checkout_dir}/post-receive"),
    mode    => "0755"
}

# Give the deploy user puppet powers. but only puppet powers.

augeas { "sudoers-puppet-cmd":
    context => "/files/etc/sudoers.d/deploy",
    changes => [
        "set Cmnd_Alias[alias/name = 'SERVICES']/alias/name SERVICES",
        "set Cmnd_Alias[alias/name = 'SERVICES']/alias/command[1] /usr/bin/gem",
        "set Cmnd_Alias[alias/name = 'SERVICES']/alias/command[2] /usr/bin/puppet",
    ]
} 

augeas { "sudoers-defaults-notty":
    context => "/files/etc/sudoers.d/deploy",
    changes => [
        'set Defaults[type=":deploy"]/type ":deploy"',
        'set Defaults[type=":deploy"]/requiretty/negate ""'
    ]
} 

# 
augeas {"deploy-sudoers":
    context => "/files/etc/sudoers.d/deploy",
    changes => [
        # allow wheel users to use sudo
        'set spec[user = "deploy"]/user deploy',
        'set spec[user = "deploy"]/host_group/host ALL',
        'set spec[user = "deploy"]/host_group/command SERVICES',
        'set spec[user = "deploy"]/host_group/command/runas_user root',
        'set spec[user = "deploy"]/host_group/command/tag NOPASSWD',
    ]
}

# Groups and users are required to do anything else.
# Uses file and exec selectors to declare that the users are needed for 
# everything.
Group["deploy"] -> User["deploy"] -> File <| |>
User["deploy"] -> Exec <| |>

Package["git"] -> Exec["git-init"]
Package["git"] -> Exec["git-branch-create"]
Package["git"] -> Exec["git-branch-checkout"]

# git-branch will be notified when git-init happens.
# This should, therefore, only ever happen once.
Exec["git-init"] ~> Exec["git-branch-create"] -> Exec["git-branch-checkout"]

# We need the repo directory to exist before we init it.
File[$deploy_repo] -> Exec["git-init"]

# Augeas stuff.
User["deploy"] -> 
Augeas["sudoers-puppet-cmd"] ->
Augeas["sudoers-defaults-notty"] ->
Augeas["deploy-sudoers"]

# Class: install_server::tftp_server
#
# This class installs and configures atftpd
#
# Parameters:
#
# Actions:
#   Install and configure atftpd and populate tftp directory structures
#
# Requires:
#
# Sample Usage:
#   include install_server::tftp_server

class install_server::tftp_server (
    String $ztp_juniper_root_password,
) {

    file { '/srv/tftpboot':
        # config files in the puppet repository,
        # larger files like binary images in volatile
        source       => [
            'puppet:///modules/install_server/tftpboot',
            # lint:ignore:puppet_url_without_modules
            'puppet:///volatile/tftpboot',
            # lint:endignore
        ],
        sourceselect => all,
        mode         => '0444',
        owner        => 'root',
        group        => 'root',
        recurse      => remote,
        backup       => false,
    }

    $homer_key = secret('keyholder/homer.pub')
    file { '/srv/tftpboot/ztp-juniper.sh':
        owner   => 'root',
        group   => 'root',
        mode    => '0444',  # Required for atftp to read it, runs as nobody
        content => template('install_server/tftpboot/ztp-juniper.sh.erb'),
    }

    file { '/etc/default/atftpd':
        mode   => '0444',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/install_server/atftpd-default',
        notify => Service['atftpd'],
    }

    package { 'atftpd':
        ensure  => present,
        require => File['/etc/default/atftpd'],
    }

    service { 'atftpd':
        hasstatus => false,
        require   => Package['atftpd'],
    }

    profile::auto_restarts::service { 'atftpd': }
}

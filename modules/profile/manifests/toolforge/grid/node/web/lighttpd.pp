# Class: profile::toolforge::grid::node::web::lighttpd
#
# This configures the compute node as a lighttpd web server
#
# Parameters:
#
# Actions:
#
# Requires:
#
# Sample Usage:
#
class profile::toolforge::grid::node::web::lighttpd(
    $collectors = lookup('profile::toolforge::grid::base::collectors'),
) {
    include profile::toolforge::grid::node::web

    $php_cgi_package = debian::codename() ? {
        'buster'  => 'php7.3-cgi',
        default   => fail('unsupported debian version'),
    }

    package { $php_cgi_package:
        ensure => latest,
    }

    package { [
        'lighttpd',
        'lighttpd-mod-magnet',        #T70614
        ]:
        ensure  => latest,
        require => File['/var/run/lighttpd'],
    }

    service { 'lighttpd':
        ensure  => stopped,
        require => Package['lighttpd'],
    }

    sonofgridengine::join { "queues-${facts['fqdn']}":
        sourcedir => "${collectors}/queues",
        list      => [ 'webgrid-lighttpd' ],
    }

    file { '/var/run/lighttpd':
        ensure => directory,
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '1777',
    }

    # Override dpkg to specify mode 1777 for /var/run/lighttpd
    #
    #  Without this, lighttpd's init script recreates the directory
    #  on startup with the wrong permissions.
    #
    #  TT142932
    exec { 'var-run-lighttpd-permissions':
        command => '/usr/bin/dpkg-statoverride --add www-data www-data 1777 /var/run/lighttpd',
        unless  => '/usr/bin/dpkg-statoverride --list /var/run/lighttpd',
    }
}

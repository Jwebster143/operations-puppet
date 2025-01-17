# SPDX-License-Identifier: Apache-2.0
# setup a webserver for misc. apps
class profile::miscweb::httpd (
    Stdlib::Fqdn $deployment_server = lookup('deployment_server'),
){

    $apache_modules_common = ['rewrite', 'headers', 'proxy', 'proxy_http']

    if (debian::codename::ge('bullseye')) {
        $apache_php_module = 'php7.4'
    } else {
        $apache_php_module = 'php7.3'
    }

    $apache_modules = concat($apache_modules_common, $apache_php_module)

    ensure_packages('libapache2-mod-php')

    class { '::httpd':
        modules => $apache_modules,
    }

    class { '::httpd::mpm':
        mpm    => 'prefork',
    }

    httpd::mod_conf { 'authnz_ldap':
        ensure => present,
    }

    profile::auto_restarts::service { 'apache2': }
    profile::auto_restarts::service { 'envoyproxy': }

    ferm::service { 'miscweb-http-envoy':
        proto  => 'tcp',
        port   => '80',
        srange => "(${::ipaddress} ${::ipaddress6})"
    }

    ferm::service { 'miscweb-http-deployment':
        proto  => 'tcp',
        port   => '80',
        srange => "(@resolve((${deployment_server})) @resolve((${deployment_server}), AAAA))"
    }

    rsyslog::input::file { 'miscweb-apache2-error':
        path => '/var/log/apache2/*error*.log',
    }

    rsyslog::input::file { 'miscweb-apache2-access':
        path => '/var/log/apache2/*access*.log',
    }
}

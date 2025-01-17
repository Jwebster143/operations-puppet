# SPDX-License-Identifier: Apache-2.0
# @summary Installs a proxy server for the install server
# @param ensure ensurable parameter
# @param structured_logs use the cee structured logs format
# @param ssl_ports list of ssl ports
# @param safe_ports list of safe ports
# @param ssh_acl An acl listing rles that are allowed to proxy ssh and the destination ips they are allowed to proxy too
class profile::installserver::proxy(
    Wmflib::Ensure              $ensure          = lookup('profile::installserver::proxy::ensure'),
    Boolean                     $structured_logs = lookup('profile::installserver::proxy::structured_logs'),
    Array[Stdlib::Port]         $ssl_ports       = lookup('profile::installserver::proxy::ssl_ports'),
    Array[Stdlib::Port]         $safe_ports      = lookup('profile::installserver::proxy::safe_ports'),
    Hash[String[1], Squid::Acl] $ssh_acls        = lookup('profile::installserver::proxy::ssh_acls')
){
    include network::constants
    include profile::logrotate
    $prod_networks = $network::constants::production_networks
    $_ssh_acls = squid::acl::normalise($ssh_acls)

    $syslog_facility = 'local0'
    $syslog_priority = 'info'
    class { 'squid':
        ensure              => $ensure,
        config_content      => template('role/caching-proxy/squid.conf.erb'),
        logrotate_frequency => $profile::logrotate::hourly.bool2str('hourly', 'daily'),
    }

    profile::auto_restarts::service { 'squid': }

    $rsyslog_content = @("CONF"/L$)
    # Send squid access logs
    if \$programname startswith 'squid' \
    and  \$syslogfacility-text == '${syslog_facility}' \
    and \$syslogpriority-text == '${syslog_priority}' \
    then /var/log/squid/access.log
    &~
    | CONF

    rsyslog::conf { 'squid-access':
        content => $rsyslog_content,
    }
    systemd::timer::job { 'squid-logrotate':
        ensure      => $ensure,
        user        => 'root',
        description => 'rotate squid proxy log files',
        command     => '/usr/sbin/squid -k rotate',
        interval    => {'start' => 'OnCalendar', 'interval' => '*-*-* 17:15:00'},
    }

    ferm::service { 'proxy':
        proto  => 'tcp',
        port   => '8080',
        srange => '$PRODUCTION_NETWORKS',
    }

    # Monitoring
    monitoring::service { 'squid':
        ensure        => $ensure,
        description   => 'Squid',
        check_command => 'check_tcp!8080',
        notes_url     => 'https://wikitech.wikimedia.org/wiki/HTTP_proxy',
    }
}

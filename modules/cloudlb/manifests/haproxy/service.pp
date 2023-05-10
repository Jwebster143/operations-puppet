# SPDX-License-Identifier: Apache-2.0
define cloudlb::haproxy::service (
    CloudLB::HAProxy::Service::Definition $service,
) {
    # shortcuts
    $servers = $service['backend']['servers']
    $port_backend = $service['backend']['port']
    $frontends = $service['frontends']
    $type = $service['type']
    $open_firewall = $service['open_firewall']
    $healthcheck_options = $service['healthcheck']['options']
    $healthcheck_method = $service['healthcheck']['method']
    $healthcheck_path = $service['healthcheck']['path']
    $firewall = $service['firewall']

    if $type == 'http' {
        file { "/etc/haproxy/conf.d/${title}.cfg":
            ensure  => present,
            owner   => 'root',
            group   => 'root',
            mode    => '0444',
            content => template('cloudlb/haproxy/conf.d/http-service.cfg.erb'),
            # restart to pick up new config files in conf.d
            notify  => Service['haproxy'],
        }
    } elsif $type == 'tcp' {
        file { "/etc/haproxy/conf.d/${title}.cfg":
            ensure  => present,
            owner   => 'root',
            group   => 'root',
            mode    => '0444',
            content => template('cloudlb/haproxy/conf.d/tcp-service.cfg.erb'),
            # restart to pick up new config files in conf.d
            notify  => Service['haproxy'],
        }
    } else {
        fail("Unknown service type ${type}")
    }

    $frontends.each | Integer $index, CloudLB::HAProxy::Service::Frontend $frontend | {
        if $firewall['restricted_to_fqdns'] {
            # TODO: no IPv6 support, but we don't care at the moment
            # TODO: no support for multiple A records, but we don't care at the moment
            $ips = $firewall['restricted_to_fqdns'].map |$host| {
                        dnsquery::a($host)[0]
                    }.join(' ')
            $srange = "(${ips})"
        } else {
            if $firewall['open_to_internet'] {
                $srange = undef
            } else {
                $cidrs = join(concat($::network::constants::production_networks, $::network::constants::labs_networks), ' ')
                $srange = "(${cidrs})"
            }
        }

        $port = $frontend['port']

        ferm::service { "${title}_${port}":
            ensure => present,
            proto  => 'tcp',
            port   => $port,
            srange => $srange,
        }
    }
}

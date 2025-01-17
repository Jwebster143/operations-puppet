# SPDX-License-Identifier: Apache-2.0
class profile::wmcs::metricsinfra::haproxy (
    Array[Stdlib::Fqdn] $prometheus_alertmanager_hosts = lookup('profile::wmcs::metricsinfra::prometheus_alertmanager_hosts'),
    Stdlib::Fqdn        $alertmanager_active_host = lookup('profile::wmcs::metricsinfra::alertmanager_active_host'),
    Array[Stdlib::Fqdn] $thanos_fe_hosts = lookup('profile::wmcs::metricsinfra::thanos_fe_hosts'),
    Array[Stdlib::Fqdn] $config_manager_hosts = lookup('profile::wmcs::metricsinfra::config_manager_hosts'),
    Array[Stdlib::Fqdn] $grafana_hosts = lookup('profile::wmcs::metricsinfra::grafana_hosts'),
) {
    class { 'haproxy::cloud::base': }

    file { '/etc/haproxy/conf.d/prometheus.cfg':
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => epp(
            'profile/wmcs/metricsinfra/haproxy/prometheus.cfg.epp',
            {
                prometheus_alertmanager_hosts => $prometheus_alertmanager_hosts,
                alertmanager_active_host      => $alertmanager_active_host,
                thanos_fe_hosts               => $thanos_fe_hosts,
                config_manager_hosts          => $config_manager_hosts,
                grafana_hosts                 => $grafana_hosts,
            },
        ),
        notify  => Service['haproxy'],
    }

    class { '::prometheus::haproxy_exporter':
        listen_port => 9901,
    }
}

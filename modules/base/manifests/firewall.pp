# Don't include this sub class on all hosts yet
# NOTE: Policy is DROP by default
# @param manage_nf_conntrack if false dont increase the nf_conntrack hashsize useful when using docker
#  where you are unable to write to the sys file
class base::firewall (
    Array[Stdlib::IP::Address] $monitoring_hosts        = [],
    Array[Stdlib::IP::Address] $cumin_masters           = [],
    Array[Stdlib::IP::Address] $bastion_hosts           = [],
    Array[Stdlib::IP::Address] $cache_hosts             = [],
    Array[Stdlib::IP::Address] $kafka_brokers_main      = [],
    Array[Stdlib::IP::Address] $kafka_brokers_jumbo     = [],
    Array[Stdlib::IP::Address] $kafka_brokers_logging   = [],
    Array[Stdlib::IP::Address] $kafkamon_hosts          = [],
    Array[Stdlib::IP::Address] $zookeeper_hosts_main    = [],
    Array[Stdlib::IP::Address] $druid_public_hosts      = [],
    Array[Stdlib::IP::Address] $labstore_hosts          = [],
    Array[Stdlib::IP::Address] $mysql_root_clients      = [],
    Array[Stdlib::IP::Address] $deployment_hosts        = [],
    Array[Stdlib::Host]        $prometheus_hosts        = [],
    Boolean                    $default_reject          = false,
    Boolean                    $manage_nf_conntrack     = true,
) {
    include network::constants
    include ferm

    ferm::conf { 'defs':
        prio    => '00',
        content => template('base/firewall/defs.erb'),
    }
    ferm::rule { 'default-reject':
        ensure => $default_reject.bool2str('present', 'absent'),
        prio   => '99',
        rule   => 'REJECT;'
    }

    # Increase the size of conntrack table size (default is 65536)
    sysctl::parameters { 'ferm_conntrack':
        values => {
            'net.netfilter.nf_conntrack_max'                   => 262144,
            'net.netfilter.nf_conntrack_tcp_timeout_time_wait' => 65,
        },
    }

    if $manage_nf_conntrack {
        # The sysctl value net.netfilter.nf_conntrack_buckets is read-only. It is configured
        # via a modprobe parameter, bump it manually for running systems
        exec { 'bump nf_conntrack hash table size':
            command => '/bin/echo 32768 > /sys/module/nf_conntrack/parameters/hashsize',
            onlyif  => "/bin/grep --invert-match --quiet '^32768$' /sys/module/nf_conntrack/parameters/hashsize",
        }
    }

    ferm::conf { 'main':
        prio   => '02',
        source => 'puppet:///modules/base/firewall/main-input-default-drop.conf',
    }

    $bastion_hosts_str = join($bastion_hosts, ' ')
    ferm::rule { 'bastion-ssh':
        rule   => "proto tcp dport ssh saddr (${bastion_hosts_str}) ACCEPT;",
    }

    if !empty($monitoring_hosts) {
        $monitoring_hosts_str = join($monitoring_hosts, ' ')
        ferm::rule { 'monitoring-all':
            rule   => "saddr (${monitoring_hosts_str}) ACCEPT;",
        }
    }

    if !empty($prometheus_hosts) {
        ferm::rule { 'prometheus-all':
            rule   => "saddr @resolve((${prometheus_hosts.join(' ')})) ACCEPT;",
        }
    }

    ferm::service { 'ssh-from-cumin-masters':
        proto  => 'tcp',
        port   => '22',
        srange => '$CUMIN_MASTERS',
    }

    nrpe::plugin { 'check_conntrack':
        source => 'puppet:///modules/base/firewall/check_conntrack.py',
    }

    nrpe::monitor_service { 'conntrack_table_size':
        description   => 'Check size of conntrack table',
        nrpe_command  => '/usr/local/lib/nagios/plugins/check_conntrack 80 90',
        contact_group => 'admins',
        notes_url     => 'https://wikitech.wikimedia.org/wiki/Monitoring/check_conntrack',
    }

    nrpe::plugin { 'check_ferm':
        source => 'puppet:///modules/base/firewall/check_ferm',
    }

    nrpe::monitor_service { 'ferm_active':
        description    => 'Check whether ferm is active by checking the default input chain',
        nrpe_command   => '/usr/local/lib/nagios/plugins/check_ferm',
        sudo_user      => 'root',
        contact_group  => 'admins',
        notes_url      => 'https://wikitech.wikimedia.org/wiki/Monitoring/check_ferm',
        check_interval => 30,
    }
}

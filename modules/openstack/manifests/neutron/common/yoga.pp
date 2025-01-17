# SPDX-License-Identifier: Apache-2.0

class openstack::neutron::common::yoga(
    Array[Stdlib::Fqdn] $openstack_controllers,
    Array[Stdlib::Fqdn] $rabbitmq_nodes,
    Stdlib::Fqdn $keystone_fqdn,
    $db_pass,
    $db_user,
    $db_host,
    $region,
    $dhcp_domain,
    $ldap_user_pass,
    $rabbit_user,
    $rabbit_pass,
    $log_agent_heartbeats,
    $agent_down_time,
    Stdlib::Port $bind_port,
    ) {

    class { "openstack::neutron::common::yoga::${::lsbdistcodename}": }

    # Subtemplates of neutron.conf are going to want to know what
    #  version this is
    $version = inline_template("<%= @title.split(':')[-1] -%>")
    $keystone_auth_username = 'novaadmin'
    $keystone_auth_project = 'admin'
    file { '/etc/neutron/neutron.conf':
            owner     => 'neutron',
            group     => 'neutron',
            mode      => '0660',
            show_diff => false,
            content   => template('openstack/yoga/neutron/neutron.conf.erb'),
            require   => Package['neutron-common'];
    }

    file { '/etc/neutron/policy.yaml':
            owner   => 'root',
            group   => 'root',
            mode    => '0644',
            source  => 'puppet:///modules/openstack/yoga/neutron/policy.yaml',
            require => Package['neutron-common'];
    }

    file { '/etc/neutron/plugins/ml2/ml2_conf.ini':
        owner   => 'neutron',
        group   => 'neutron',
        mode    => '0744',
        content => template('openstack/yoga/neutron/plugins/ml2/ml2_conf.ini.erb'),
        require => Package['neutron-common'];
    }
}

# SPDX-License-Identifier: Apache-2.0
class profile::openstack::codfw1dev::galera::node(
    Integer             $server_id             = lookup('profile::openstack::codfw1dev::galera::server_id'),
    Boolean             $enabled               = lookup('profile::openstack::codfw1dev::galera::enabled'),
    Stdlib::Port        $listen_port           = lookup('profile::openstack::codfw1dev::galera::listen_port'),
    String              $prometheus_db_pass    = lookup('profile::openstack::codfw1dev::galera::prometheus_db_pass'),
    Array[Stdlib::Fqdn] $openstack_controllers = lookup('profile::openstack::codfw1dev::openstack_controllers'),
    Array[Stdlib::Fqdn] $designate_hosts       = lookup('profile::openstack::codfw1dev::designate_hosts'),
    Array[Stdlib::Fqdn] $labweb_hosts          = lookup('profile::openstack::codfw1dev::labweb_hosts'),
    Array[Stdlib::Fqdn] $cinder_backup_nodes   = lookup('profile::openstack::codfw1dev::cinder::backup::nodes'),
    Array[Stdlib::Fqdn] $haproxy_nodes         = lookup('profile::openstack::codfw1dev::haproxy_nodes'),
) {
    class {'::profile::openstack::base::galera::node':
        server_id             => $server_id,
        enabled               => $enabled,
        listen_port           => $listen_port,
        openstack_controllers => $openstack_controllers,
        designate_hosts       => $designate_hosts,
        labweb_hosts          => $labweb_hosts,
        prometheus_db_pass    => $prometheus_db_pass,
        cinder_backup_nodes   => $cinder_backup_nodes,
        haproxy_nodes         => $haproxy_nodes,
    }
}

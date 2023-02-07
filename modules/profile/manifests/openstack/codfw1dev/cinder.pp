# SPDX-License-Identifier: Apache-2.0
class profile::openstack::codfw1dev::cinder(
    String $version = lookup('profile::openstack::codfw1dev::version'),
    Array[Stdlib::Fqdn] $openstack_controllers = lookup('profile::openstack::codfw1dev::openstack_controllers'),
    Array[Stdlib::Fqdn] $rabbitmq_nodes = lookup('profile::openstack::codfw1dev::rabbitmq_nodes'),
    Stdlib::Fqdn $keystone_fqdn = lookup('profile::openstack::codfw1dev::keystone_api_fqdn'),
    String $db_pass = lookup('profile::openstack::codfw1dev::cinder::db_pass'),
    Stdlib::Fqdn $db_host = lookup('profile::openstack::codfw1dev::cinder::db_host'),
    Stdlib::Port $api_bind_port = lookup('profile::openstack::codfw1dev::cinder::api_bind_port'),
    String $ceph_pool = lookup('profile::openstack::codfw1dev::cinder::ceph_pool'),
    String $rabbit_pass = lookup('profile::openstack::codfw1dev::nova::rabbit_pass'),
    String $ldap_user_pass = lookup('profile::openstack::codfw1dev::ldap_user_pass'),
    String $region = lookup('profile::openstack::codfw1dev::region'),
    Hash   $cinder_backup_volumes = lookup('profile::openstack::codfw1dev::cinder_backup_volumes'),
    String[1]           $ceph_rbd_client_name  = lookup('profile::openstack::codfw1dev::cinder::ceph_rbd_client_name'),
    Array[Stdlib::Fqdn] $haproxy_nodes         = lookup('profile::openstack::codfw1dev::haproxy_nodes'),
) {
    class {'::profile::openstack::base::cinder':
        version               => $version,
        openstack_controllers => $openstack_controllers,
        rabbitmq_nodes        => $rabbitmq_nodes,
        keystone_fqdn         => $keystone_fqdn,
        db_pass               => $db_pass,
        db_host               => $db_host,
        api_bind_port         => $api_bind_port,
        ceph_pool             => $ceph_pool,
        ceph_rbd_client_name  => $ceph_rbd_client_name,
        ldap_user_pass        => $ldap_user_pass,
        rabbit_pass           => $rabbit_pass,
        region                => $region,
        active                => true,
        cinder_backup_volumes => $cinder_backup_volumes,
        haproxy_nodes         => $haproxy_nodes,
        cinder_volume_nodes   => wmflib::class::hosts('profile::openstack::codfw1dev::cinder::volume')
    }
}

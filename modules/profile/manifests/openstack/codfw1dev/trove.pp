class profile::openstack::codfw1dev::trove(
    String              $version                 = lookup('profile::openstack::codfw1dev::version'),
    Integer             $workers                 = lookup('profile::openstack::codfw1dev::trove::workers'),
    Array[Stdlib::Fqdn] $openstack_controllers   = lookup('profile::openstack::codfw1dev::openstack_controllers'),
    Array[Stdlib::Fqdn] $rabbitmq_nodes          = lookup('profile::openstack::codfw1dev::rabbitmq_nodes'),
    String              $db_pass                 = lookup('profile::openstack::codfw1dev::trove::db_pass'),
    String              $db_name                 = lookup('profile::openstack::codfw1dev::trove::db_name'),
    Stdlib::Fqdn        $db_host                 = lookup('profile::openstack::codfw1dev::trove::db_host'),
    String              $ldap_user_pass          = lookup('profile::openstack::codfw1dev::ldap_user_pass'),
    Stdlib::Fqdn        $keystone_fqdn           = lookup('profile::openstack::codfw1dev::keystone_api_fqdn'),
    String              $region                  = lookup('profile::openstack::codfw1dev::region'),
    String              $rabbit_pass             = lookup('profile::openstack::codfw1dev::nova::rabbit_pass'),
    String              $trove_guest_rabbit_pass = lookup('profile::openstack::codfw1dev::trove::trove_guest_rabbit_pass'),
    String              $trove_service_user_pass = lookup('profile::openstack::codfw1dev::trove::trove_user_pass'),
    String              $trove_quay_user         = lookup('profile::openstack::codfw1dev::trove::quay_user'),
    String              $trove_quay_pass         = lookup('profile::openstack::codfw1dev::trove::quay_pass'),
    String              $trove_dns_zone          = lookup('profile::openstack::codfw1dev::trove::dns_zone'),
    String              $trove_dns_zone_id       = lookup('profile::openstack::codfw1dev::trove::dns_zone_id'),
    Array[Stdlib::Fqdn] $haproxy_nodes           = lookup('profile::openstack::codfw1dev::haproxy_nodes'),
) {
    class {'::profile::openstack::base::trove':
        version                 => $version,
        workers                 => $workers,
        openstack_controllers   => $openstack_controllers,
        rabbitmq_nodes          => $rabbitmq_nodes,
        db_pass                 => $db_pass,
        db_name                 => $db_name,
        db_host                 => $db_host,
        ldap_user_pass          => $ldap_user_pass,
        keystone_fqdn           => $keystone_fqdn,
        region                  => $region,
        rabbit_pass             => $rabbit_pass,
        trove_guest_rabbit_pass => $trove_guest_rabbit_pass,
        trove_service_user_pass => $trove_service_user_pass,
        trove_quay_user         => $trove_quay_user,
        trove_quay_pass         => $trove_quay_pass,
        trove_dns_zone          => $trove_dns_zone,
        trove_dns_zone_id       => $trove_dns_zone_id,
        haproxy_nodes           => $haproxy_nodes,
    }
}

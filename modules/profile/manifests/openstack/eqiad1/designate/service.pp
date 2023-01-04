class profile::openstack::eqiad1::designate::service(
    $version = lookup('profile::openstack::eqiad1::version'),
    Array[Stdlib::Fqdn] $designate_hosts = lookup('profile::openstack::eqiad1::designate_hosts'),
    Array[Stdlib::Fqdn] $openstack_controllers = lookup('profile::openstack::eqiad1::openstack_controllers'),
    Stdlib::Fqdn $keystone_fqdn = lookup('profile::openstack::eqiad1::keystone_api_fqdn'),
    $puppetmaster_hostname = lookup('profile::openstack::eqiad1::puppetmaster_hostname'),
    $db_pass = lookup('profile::openstack::eqiad1::designate::db_pass'),
    $db_host = lookup('profile::openstack::eqiad1::designate::db_host'),
    $domain_id_internal_forward = lookup('profile::openstack::eqiad1::designate::domain_id_internal_forward'),
    $domain_id_internal_forward_legacy = lookup('profile::openstack::eqiad1::designate::domain_id_internal_forward_legacy'),
    $domain_id_internal_reverse = lookup('profile::openstack::eqiad1::designate::domain_id_internal_reverse'),
    $ldap_user_pass = lookup('profile::openstack::eqiad1::ldap_user_pass'),
    $pdns_api_key = lookup('profile::openstack::eqiad1::pdns::api_key'),
    $db_admin_pass = lookup('profile::openstack::eqiad1::designate::db_admin_pass'),
    Array[Stdlib::Fqdn] $pdns_hosts = lookup('profile::openstack::eqiad1::pdns::hosts'),
    Array[Stdlib::Fqdn] $rabbitmq_nodes = lookup('profile::openstack::eqiad1::rabbitmq_nodes'),
    $rabbit_pass = lookup('profile::openstack::eqiad1::nova::rabbit_pass'),
    $osm_host = lookup('profile::openstack::eqiad1::osm_host'),
    $region = lookup('profile::openstack::eqiad1::region'),
    Integer $mcrouter_port = lookup('profile::openstack::eqiad1::designate::mcrouter_port'),
    Array[Stdlib::Host] $haproxy_nodes = lookup('profile::openstack::eqiad1::haproxy_nodes'),
) {

    require ::profile::openstack::eqiad1::clientpackages
    class{'::profile::openstack::base::designate::service':
        version                           => $version,
        designate_hosts                   => $designate_hosts,
        keystone_fqdn                     => $keystone_fqdn,
        db_pass                           => $db_pass,
        db_host                           => $db_host,
        domain_id_internal_forward        => $domain_id_internal_forward,
        domain_id_internal_forward_legacy => $domain_id_internal_forward_legacy,
        domain_id_internal_reverse        => $domain_id_internal_reverse,
        puppetmaster_hostname             => $puppetmaster_hostname,
        openstack_controllers             => $openstack_controllers,
        ldap_user_pass                    => $ldap_user_pass,
        pdns_api_key                      => $pdns_api_key,
        db_admin_pass                     => $db_admin_pass,
        pdns_hosts                        => $pdns_hosts,
        rabbitmq_nodes                    => $rabbitmq_nodes,
        rabbit_pass                       => $rabbit_pass,
        osm_host                          => $osm_host,
        region                            => $region,
        mcrouter_port                     => $mcrouter_port,
        haproxy_nodes                     => $haproxy_nodes,
    }

    class {'::openstack::designate::monitor':
        active         => true,
        contact_groups => 'wmcs-team-email',
    }
}

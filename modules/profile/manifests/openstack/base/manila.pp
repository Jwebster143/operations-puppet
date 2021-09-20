class profile::openstack::base::manila (
    String              $version                      = lookup('profile::openstack::base::version'),
    String              $region                       = lookup('profile::openstack::base::region'),
    Array[Stdlib::Fqdn] $openstack_controllers        = lookup('profile::openstack::base::openstack_controllers'),
    Stdlib::Fqdn        $keystone_api_fqdn            = lookup('profile::openstack::base::keystone_api_fqdn'),
    String              $ldap_user_pass               = lookup('profile::openstack::base::ldap_user_pass'),
    Boolean             $manila_service_enabled       = lookup('profile::openstack::base::manila::service_enabled'),
    String              $cinder_volume_type           = lookup('profile::openstack::base::manila::cinder_volume_type'),
    String              $db_user                      = lookup('profile::openstack::base::manila::db_user'),
    String              $db_pass                      = lookup('profile::openstack::base::manila::db_pass'),
    String              $db_name                      = lookup('profile::openstack::base::manila::db_name'),
    String              $db_host                      = lookup('profile::openstack::base::manila::db_host'),
    String              $nova_flavor_id               = lookup('profile::openstack::base::manila::nova_flavor_id'),
    String              $neutron_network              = lookup('profile::openstack::base::manila::neutron_network'),
    String              $metadata_proxy_shared_secret = lookup('profile::openstack::base::neutron::metadata_proxy_shared_secret'),
    ) {

    class { 'openstack::manila':
        enabled                      => $manila_service_enabled,
        version                      => $version,
        region                       => $region,
        openstack_controllers        => $openstack_controllers,
        keystone_api_fqdn            => $keystone_api_fqdn,
        ldap_user_pass               => $ldap_user_pass,
        cinder_volume_type           => $cinder_volume_type,
        db_user                      => $db_user,
        db_pass                      => $db_pass,
        db_name                      => $db_name,
        db_host                      => $db_host,
        nova_flavor_id               => $nova_flavor_id,
        neutron_network              => $neutron_network,
        metadata_proxy_shared_secret => $metadata_proxy_shared_secret,
    }
}

# SPDX-License-Identifier: Apache-2.0
class profile::openstack::codfw1dev::cloudgw (
    Stdlib::IP::Address           $routing_source = lookup('profile::openstack::codfw1dev::cloudgw::routing_source_ip',{default_value => '185.15.57.1'}),
    Stdlib::IP::Address::V4::CIDR $virt_subnet    = lookup('profile::openstack::codfw1dev::cloudgw::virt_subnet_cidr', {default_value => '172.16.128.0/24'}),
    Integer                       $virt_vlan      = lookup('profile::openstack::codfw1dev::cloudgw::virt_vlan',        {default_value => 2107}),
    Stdlib::IP::Address           $virt_peer      = lookup('profile::openstack::codfw1dev::cloudgw::virt_peer',        {default_value => '127.0.0.5'}),
    Stdlib::IP::Address::V4::CIDR $virt_floating  = lookup('profile::openstack::codfw1dev::cloudgw::virt_floating',    {default_value => '127.0.0.5/24'}),
    Optional[Stdlib::IP::Address::V4::CIDR] $virt_floating_additional  = lookup('profile::openstack::eqiad1::cloudgw::virt_floating_additional',    {default_value => undef}),
    Integer                       $wan_vlan       = lookup('profile::openstack::codfw1dev::cloudgw::wan_vlan',         {default_value => 2120}),
    Stdlib::IP::Address           $wan_addr       = lookup('profile::openstack::codfw1dev::cloudgw::wan_addr',         {default_value => '127.0.0.4'}),
    Integer                       $wan_netm       = lookup('profile::openstack::codfw1dev::cloudgw::wan_netm',         {default_value => 8}),
    Stdlib::IP::Address           $wan_gw         = lookup('profile::openstack::codfw1dev::cloudgw::wan_gw',           {default_value => '127.0.0.1'}),
    Array[String]                 $vrrp_vips      = lookup('profile::openstack::codfw1dev::cloudgw::vrrp_vips',        {default_value => ['127.0.0.1 dev eno2']}),
    Stdlib::IP::Address           $vrrp_peer      = lookup('profile::openstack::codfw1dev::cloudgw::vrrp_peer',        {default_value => '127.0.0.1'}),
    Hash                          $conntrackd     = lookup('profile::openstack::codfw1dev::cloudgw::conntrackd',       {default_value => {}}),
    Stdlib::IP::Address::V4::CIDR $transport_cidr = lookup('profile::openstack::codfw1dev::cloudgw::transport_cidr'),
    Stdlib::IP::Address::V4::Nosubnet $transport_vip = lookup('profile::openstack::codfw1dev::cloudgw::transport_vip'),
) {
    class { '::profile::openstack::base::cloudgw':
        routing_source           => $routing_source,
        virt_subnet              => $virt_subnet,
        virt_vlan                => $virt_vlan,
        virt_peer                => $virt_peer,
        virt_floating            => $virt_floating,
        virt_floating_additional => $virt_floating_additional,
        virt_cidr                => $virt_subnet,
        wan_vlan                 => $wan_vlan,
        wan_addr                 => $wan_addr,
        wan_netm                 => $wan_netm,
        wan_gw                   => $wan_gw,
        vrrp_vips                => $vrrp_vips,
        vrrp_peer                => $vrrp_peer,
        conntrackd               => $conntrackd,
        transport_cidr           => $transport_cidr,
        transport_vip            => $transport_vip,
    }
    contain '::profile::openstack::base::cloudgw'
}

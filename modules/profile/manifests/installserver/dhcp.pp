# SPDX-License-Identifier: Apache-2.0
# Installs a DHCP server and configures it for WMF
class profile::installserver::dhcp(
  Enum['stopped', 'running']               $ensure_service = lookup('profile::installserver::dhcp::ensure_service'),
  Hash[Wmflib::Sites, Stdlib::IP::Address] $tftp_servers   = lookup('profile::installserver::dhcp::tftp_servers'),
){

  include network::constants
  class { 'install_server::dhcp_server':
    ensure_service => $ensure_service,
    mgmt_networks  => $network::constants::mgmt_networks_bydc,
    tftp_servers   => $tftp_servers,
  }

  ferm::service { 'dhcp':
    proto  => 'udp',
    port   => 'bootps',
    srange => '($PRODUCTION_NETWORKS $NETWORK_INFRA)',
  }
}

# SPDX-License-Identifier: Apache-2.0
#
# Class: profile::ceph::client:rbd_backy
#
# This profile will configure clients for connecting to Ceph rados block storage
# for the purposes of making snapshots and backing them up with backy2.
class profile::ceph::client::rbd_backy(
    Boolean                    $enable_v2_messenger       = lookup('profile::ceph::client::rbd::enable_v2_messenger'),
    Hash[String,Hash]          $mon_hosts                 = lookup('profile::ceph::mon::hosts'),
    Hash[String,Hash]          $osd_hosts                 = lookup('profile::ceph::osd::hosts'),
    Array[Stdlib::IP::Address] $cluster_networks          = lookup('profile::ceph::cluster_networks'),
    Array[Stdlib::IP::Address] $public_networks           = lookup('profile::ceph::public_networks'),
    Stdlib::Unixpath           $data_dir                  = lookup('profile::ceph::data_dir'),
    String                     $client_name               = lookup('profile::ceph::client::rbd::client_name'),
    String                     $cinder_client_name        = lookup('profile::ceph::client::rbd::cinder_client_name'),
    String                     $fsid                      = lookup('profile::ceph::fsid'),
    String                     $ceph_repository_component = lookup('profile::ceph::ceph_repository_component'),
    Ceph::Auth::Conf           $ceph_auth_conf            = lookup('profile::ceph::auth::deploy::configuration'),
) {

    class { 'ceph::common':
        home_dir                  => $data_dir,
        ceph_repository_component => $ceph_repository_component,
    }

    class { 'ceph::config':
        cluster_networks    => $cluster_networks,
        enable_libvirt_rbd  => false,
        enable_v2_messenger => $enable_v2_messenger,
        fsid                => $fsid,
        mon_hosts           => $mon_hosts,
        public_networks     => $public_networks,
    }

    if ! $ceph_auth_conf[$client_name] {
        fail("missing '${client_name}' in ceph auth configuration")
    }
    if ! $ceph_auth_conf[$client_name]['keydata'] {
        fail("missing '${client_name}' keydata in ceph auth configuration")
    }

    if ! $ceph_auth_conf[$cinder_client_name] {
        fail("missing '${cinder_client_name}' in ceph auth configuration")
    }
    if ! $ceph_auth_conf[$cinder_client_name]['keydata'] {
        fail("missing '${cinder_client_name}' keydata in ceph auth configuration")
    }

    class { 'prometheus::node_pinger':
        nodes_to_ping => $osd_hosts.keys() + $mon_hosts.keys(),
    }
}
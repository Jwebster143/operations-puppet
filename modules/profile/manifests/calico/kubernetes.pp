# SPDX-License-Identifier: Apache-2.0
# == Class profile::calico::kubernetes
#
# Installs calico for use in a kubernetes cluster.
# This follows https://docs.projectcalico.org/getting-started/kubernetes/#manual-installation
# It also optionally deploys Istio CNI configurations, since (Istio) upstream
# suggests to use a chained config with Calico.

class profile::calico::kubernetes (
    String $kubernetes_cluster_name = lookup('profile::kubernetes::cluster_name'),
) {
    $kubernetes_cluster_config = k8s::fetch_cluster_config($kubernetes_cluster_name)
    $pki_intermediate_base = $kubernetes_cluster_config['pki_intermediate_base']
    $pki_renew_seconds = $kubernetes_cluster_config['pki_renew_seconds']
    $master_fqdn = $kubernetes_cluster_config['master']
    $cluster_nodes = $kubernetes_cluster_config['cluster_nodes']
    $calico_version = $kubernetes_cluster_config['calico_version']
    $istio_cni_version = $kubernetes_cluster_config['istio_cni_version']

    $calico_cni_username = 'calico-cni'
    $calicoctl_username = 'calicoctl'
    $istio_cni_username = 'istio-cni'

    $calicoctl_client_cert = profile::pki::get_cert($pki_intermediate_base, $calicoctl_username, {
        'renew_seconds'  => $pki_renew_seconds,
        'outdir'         => '/etc/kubernetes/pki',
    })
    class { 'calico':
        master_fqdn        => $master_fqdn,
        calicoctl_username => $calicoctl_username,
        auth_cert          => $calicoctl_client_cert,
        calico_version     => $calico_version,
    }

    # We don't install istio-cni on control-planes as they should not
    # run any workload that needs access to it's service mesh.
    # So drop the istio-cni plugin from the list of configured plugins.
    if $::fqdn in $kubernetes_cluster_config['control_plane_nodes'] {
        $cni_config = $kubernetes_cluster_config['cni_config'].reduce({}) | $memo, $value | {
            $k = $value[0]
            if $k == 'plugins' {
                $v = $value[1].filter | $plugin | {
                    $plugin['type'] != 'istio-cni'
                }
            } else {
                $v = $value[1]
            }
            $memo + { $k => $v }
        }
    } else {
        $cni_config = $kubernetes_cluster_config['cni_config']
    }

    k8s::kubelet::cni { 'calico':
        priority => 10,
        config   => $cni_config,
    }

    $calico_cni_client_cert = profile::pki::get_cert($pki_intermediate_base, $calico_cni_username, {
        'renew_seconds'  => $pki_renew_seconds,
        'outdir'         => '/etc/kubernetes/pki',
    })
    k8s::kubeconfig { '/etc/cni/net.d/calico-kubeconfig':
        master_host => $master_fqdn,
        username    => $calico_cni_username,
        auth_cert   => $calico_cni_client_cert,
        require     => File['/etc/cni/net.d'],
    }

    # Install istio-cni package and provide a kubeconfig for it in case
    # a cni plugin of type "istio-cni" is configured.
    $ensure_istio_cni = pick($cni_config['plugins'], []).filter | $plugin | {
        $plugin['type'] == 'istio-cni'
    }.empty.bool2str('absent', 'present')
    $istio_cni_version_safe = regsubst($istio_cni_version, '\.', '', 'G')
    apt::package_from_component { "istio${istio_cni_version_safe}":
        component => "component/istio${istio_cni_version_safe}",
        packages  => { 'istio-cni' => $ensure_istio_cni },
    }
    $istio_cni = profile::pki::get_cert($pki_intermediate_base, $istio_cni_username, {
        ensure           => $ensure_istio_cni,
        'renew_seconds'  => $pki_renew_seconds,
        'outdir'         => '/etc/kubernetes/pki',
    })
    k8s::kubeconfig { '/etc/cni/net.d/istio-kubeconfig':
        ensure      => $ensure_istio_cni,
        master_host => $master_fqdn,
        username    => $istio_cni_username,
        auth_cert   => $istio_cni,
        require     => File['/etc/cni/net.d'],
    }

    # TODO: We need to configure BGP peers in calico datastore (helm chart) as well.
    # Allow by default all the infra IPs (eg. routers loopback) as well as the server's gateway (eg. ToR)
    $gateways = $facts['default_routes']['ipv6'] ? {
        true    => [$facts['default_routes']['ipv4'], $facts['default_routes']['ipv6']],
        default => [$facts['default_routes']['ipv4']],
    }
    $gateways_ferm = join($gateways, ' ')
    ferm::service { 'calico-bird':
        proto  => 'tcp',
        port   => '179', # BGP
        srange => "(\$NETWORK_INFRA ${gateways_ferm})",
    }
    # All nodes need to talk to typha and it runs as hostNetwork pod
    # TODO: If and when we move to a layered BGP hierarchy, revisit the use of
    # $cluster_nodes.
    $cluster_nodes_ferm = join($cluster_nodes, ' ')
    ferm::service { 'calico-typha':
        proto  => 'tcp',
        port   => '5473',
        srange => "(@resolve((${cluster_nodes_ferm})) @resolve((${cluster_nodes_ferm}), AAAA))",
    }
}

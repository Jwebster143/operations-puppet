# SPDX-License-Identifier: Apache-2.0
# @summary
#   This class sets up and configures kube-apiserver
#
# === Parameters
# @param [K8s::KubernetesVersion] version
#   The Kubernetes version to use.
#
# @param [String] etcd_servers
#   Comma separated list of etcd server URLs.
#
# @param [Hash[String, Stdlib::Unixpath]] apiserver_cert
#   The certificate used for the apiserver.
#
# @param [Hash[String, Stdlib::Unixpath]] sa_cert
#   The certificate used for service account management (signing).
#
# @param [Hash[String, Stdlib::Unixpath]] kubelet_client_cert
#   The certificate used to authenticate against kubelets.
#
# @param [Hash[String, Stdlib::Unixpath]] frontproxy_cert
#   The certificate used for the front-proxy.
#   https://v1-23.docs.kubernetes.io/docs/tasks/extend-kubernetes/configure-aggregation-layer/
#
# @param [Stdlib::HTTPSUrl] service_account_issuer
#   The HTTPS URL of the service account issuer (usually the control-plane URL).
#
# @param [K8s::ClusterCIDR] service_cluster_cidr
#     CIDRs (IPv4, IPv6) used to allocate Service IPs.
#
# @param [Boolean] allow_privileged
#   Whether to allow privileged containers. Defaults to true as this is required for calico to run.
#
# @param [Integer] v_log_level
#   The log level for the API server. Defaults to 0.
#
# @param [Boolean] ipv6dualstack
#   Whether to enable IPv6 dual stack support. Defaults to false.
#
# @param service_node_port_range
#   Optional port range (as first and last port, including) to reserve for services with NodePort visibility.
#   Defaults to 30000-32767 if undef.
#
# @param admission_plugins
#   Optional admission plugins that should be enabled or disabled. Defaults to undef.
#   Some plugins are enabled by default and need to be explicitely disabled.
#   The defaults depend on the kubernetes version, see:
#   `kube-apiserver -h | grep admission-plugins`.
#
# @param admission_configuration
#   Optional array of admission plugin configurations (as YAML). Defaults to undef.
#   https://kubernetes.io/docs/reference/config-api/apiserver-config.v1alpha1/#apiserver-k8s-io-v1alpha1-AdmissionPluginConfiguration
#
# @param [Hash[String, Stdlib::Unixpath]] additional_sa_certs
#   Optional array of certificate keys for validation of service account tokens.
#   These will be used in addition to sa_cert.
#
class k8s::apiserver (
    K8s::KubernetesVersion $version,
    String $etcd_servers,
    Hash[String, Stdlib::Unixpath] $apiserver_cert,
    Hash[String, Stdlib::Unixpath] $sa_cert,
    Hash[String, Stdlib::Unixpath] $kubelet_client_cert,
    Hash[String, Stdlib::Unixpath] $frontproxy_cert,
    Stdlib::HTTPSUrl $service_account_issuer,
    K8s::ClusterCIDR $service_cluster_cidr,
    Boolean $allow_privileged = true,
    Integer $v_log_level = 0,
    Boolean $ipv6dualstack = false,
    Optional[Array[Stdlib::Port, 2, 2]] $service_node_port_range = undef,
    Optional[K8s::AdmissionPlugins] $admission_plugins = undef,
    Optional[Array[Hash]] $admission_configuration = undef,
    Optional[Array[Stdlib::Unixpath]] $additional_sa_certs = undef,
) {
    group { 'kube':
        ensure => present,
        system => true,
    }
    user { 'kube':
        ensure => present,
        gid    => 'kube',
        system => true,
        home   => '/nonexistent',
        shell  => '/usr/sbin/nologin',
    }

    k8s::package { 'apiserver':
        package => 'master',
        version => $version,
    }

    file { '/etc/kubernetes/infrastructure-users':
        ensure => absent,
    }

    # The admission config file needs to be available as parameter fo apiserver
    $admission_configuration_file = '/etc/kubernetes/admission-config.yaml'
    file { '/etc/default/kube-apiserver':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => template('k8s/kube-apiserver.default.erb'),
        notify  => Service['kube-apiserver'],
    }

    $admission_configuration_ensure = $admission_configuration ? {
        undef   => absent,
        default => file,
    }
    # .to_yaml in erb templates always adds a document separator so it's
    # not possible to join yaml in the template with .to_yaml from a variable.
    $admission_configuration_content = {
        apiVersion => 'apiserver.config.k8s.io/v1',
        kind       => 'AdmissionConfiguration',
        plugins    => $admission_configuration,
    }
    file { $admission_configuration_file:
        ensure  => $admission_configuration_ensure,
        content => to_yaml($admission_configuration_content),
        owner   => 'kube',
        group   => 'kube',
        mode    => '0400',
        notify  => Service['kube-apiserver'],
    }

    service { 'kube-apiserver':
        ensure => running,
        enable => true,
    }
}

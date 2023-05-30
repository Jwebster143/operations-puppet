# SPDX-License-Identifier: Apache-2.0
# @summary Profile to make sure we got a deployment server ready
# @param user_defaults user group and mode defaults
# @param services Dict of services
# @param tokens dict of tokens
# @param include_admin if true include profile::kubernetes::kubeconfig::admin
# @param helm_user_group the group used for the helm cache directory
# @param helm_home the directory where helm plugins and config live (HELM_HOME, HELM_CONFIG_HOME)
# @param helm_cache the helm cache directory (HELM_CACHE_HOME)
# @param helm_data the helm data directory (HELM_DATA_HOME)

class profile::kubernetes::deployment_server (
    Profile::Kubernetes::User_defaults $user_defaults                  = lookup('profile::kubernetes::deployment_server::user_defaults'),
    Hash[String, Hash[String,Profile::Kubernetes::Services]] $services = lookup('profile::kubernetes::deployment_server::services', { default_value => {} }),
    Hash[String, Hash[String, Hash]] $tokens                           = lookup('profile::kubernetes::infrastructure_users', { default_value => {} }),
    Boolean $include_admin                                             = lookup('profile::kubernetes::deployment_server::include_admin', { default_value => false }),
    String $helm_user_group                                            = lookup('profile::kubernetes::helm_user_group'),
    Stdlib::Unixpath $helm_home                                        = lookup('profile::kubernetes::helm_home', { default_value => '/etc/helm' }),
    Stdlib::Unixpath $helm_data                                        = lookup('profile::kubernetes::helm_data', { default_value => '/usr/share/helm' }),
    Stdlib::Unixpath $helm_cache                                       = lookup('profile::kubernetes::helm_cache', { default_value => '/var/cache/helm' }),
) {
    class { 'helm':
        helm_user_group => $helm_user_group,
        helm_home       => $helm_home,
        helm_data       => $helm_data,
        helm_cache      => $helm_cache,
    }

    ensure_packages('istioctl')

    $kubernetes_clusters = k8s::fetch_clusters()
    # For each cluster we gather the list of services and the corresponding tokens.
    # Then we build the kubernetes configs for all of them.
    $kubernetes_clusters.map | String $cluster_name, K8s::ClusterConfig $cluster_config | {
        $_tokens = $tokens[$cluster_config['cluster_group']]
        # Get all services installed on this cluster (group)
        $_services = pick($services[$cluster_config['cluster_group']], {})
        # Generate kubeconfig files for all services
        $_services.each |$srv, $data| {
            # If the namespace is undefined, use the service name.
            $namespace = $data['namespace'] ? {
                undef   => $srv,
                default => $data['namespace']
            }
            $service_ensure = $data['ensure'] ? {
                undef   => present,
                default => $data['ensure'],
            }
            $data['usernames'].each |$usr_raw| {
                $usr = $user_defaults.merge($usr_raw)
                $token = $_tokens[$usr['name']]
                # Allow overriding the kubeconfig name
                $kubeconfig_name = $usr['kubeconfig'] ? {
                    undef => $usr['name'],
                    default => $usr['kubeconfig']
                }

                $kubeconfig_path = "/etc/kubernetes/${kubeconfig_name}-${cluster_name}.config"
                # TODO: separate username data from the services structure?
                if ($token and !defined(K8s::Kubeconfig[$kubeconfig_path])) {
                    k8s::kubeconfig { $kubeconfig_path:
                        ensure      => $service_ensure,
                        master_host => $cluster_config['master'],
                        username    => $usr['name'],
                        token       => $token['token'],
                        owner       => $usr['owner'],
                        group       => $usr['group'],
                        mode        => $usr['mode'],
                        namespace   => $namespace,
                    }
                }
            }
        }
    }
    # Now if we're including the admin account, add it for every cluster in the cluster
    # group.
    if $include_admin {
        class { 'profile::kubernetes::kubeconfig::admin': }
    }

    $kube_env_services_base = $include_admin ? {
        true  => ['admin'],
        false => []
    }
    # Used to support the kube-env.sh script. A list of service names is useful
    # to create an auto-complete feature for kube_env.
    # Please note: here we're using the service names because we assume there is a user with that name
    # If not, the service will break down the assumptions kube_env does and should not be included.
    $kube_env_services = $kube_env_services_base + $services.map |$_, $srvs| {
        # Filter out services that don't have a username
        keys($srvs).filter |$svc_name| { $svc_name in $srvs[$svc_name]['usernames'].map |$u| { $u['name'] } }
    }.flatten().unique()

    $kube_env_environments = keys($kubernetes_clusters).unique()

    # Add separate environment variable file for kube-env config.
    # profile.d is sourced alphabetically, so it needs to be named such as it comes before kube-env
    file { '/etc/profile.d/kube-conf.sh':
        ensure  => file,
        content => template('profile/kubernetes/kube-conf.sh.erb'),
        mode    => '0555',
    }
    # Add a script to profile.d with functions to set the configuration for kubernetes.
    file { '/etc/profile.d/kube-env.sh':
        ensure => file,
        source => 'puppet:///modules/profile/kubernetes/kube-env.sh',
        mode   => '0555',
    }
}

# SPDX-License-Identifier: Apache-2.0
# @summary resource to configure http(s) checks for a specific service
# @param fqdn name the domainname to check
# @param target name the host part of 'instance' label to use
# @param ip4 The IP address to connect to
# @param ip6 The IP6 address to connect to
# @param ip_families indicate support for ipv4 and/or ipv6
# @param team the WMF team to alert
# @param severity The severity of the alert
# @param port the port to run a specific check on
# @param force_tls if true force ssl otherwise use port number to decide
# @param certificate_expiry_days alert when the certificate will expire sooner than days
# @param timeout the probe timeout
# @param use_client_auth use client authentication
# @param client_auth_cert path to the client auth certificate to use
# @param client_auth_key path to the client auth key to use
# @param header_matches headers which should match
# @param header_not_matches headers which should not match
# @param body_regex_matches headers which should match
# @param body_regex_not_matches headers which should not match
# @param bearer_token the bearer token to use
# @param path the path to check
# @param body the body to send in requests
# @param method the http method to use
# @param follow_redirects if the check should honour redirects
# @param site the site to perform the check from
# @param auth_username username used for basic auth
# @param auth_password password used for basic auth
# @param useragent the useragent to use
define prometheus::blackbox::check::http (
    Stdlib::Fqdn                            $fqdn                    = $title,
    Stdlib::Fqdn                            $target                  = $facts['networking']['hostname'],
    Stdlib::IP::Address::V4::Nosubnet       $ip4                     = $facts['networking']['ip'],
    Stdlib::IP::Address::V6::Nosubnet       $ip6                     = $facts['networking']['ip6'],
    Array[Enum['ip4', 'ip6']]               $ip_families             = ['ip4', 'ip6'],
    String[1]                               $team                    = 'sre',
    Prometheus::Alert::Severity             $severity                = 'critical',
    Stdlib::Port                            $port                    = 443,
    Boolean                                 $force_tls               = false,
    Integer[1,120]                          $certificate_expiry_days = 10,
    String                                  $timeout                 = '3s',
    Boolean                                 $use_client_auth         = false,
    Stdlib::Unixpath                        $client_auth_cert        = $facts['puppet_config']['hostcert'],
    Stdlib::Unixpath                        $client_auth_key         = $facts['puppet_config']['hostprivkey'],
    Array[Prometheus::Blackbox::HeaderSpec] $header_matches          = [],
    Array[Prometheus::Blackbox::HeaderSpec] $header_not_matches      = [],
    Array[String[1]]                        $body_regex_matches      = [],
    Array[String[1]]                        $body_regex_not_matches  = [],
    Optional[String[1]]                     $bearer_token            = undef,
    Stdlib::Unixpath                        $path                    = '/',
    Hash                                    $body                    = {},
    Wmflib::HTTP::Method                    $method                  = 'GET',
    Boolean                                 $follow_redirects        = false,
    Wmflib::Sites                           $site                    = $::site,  # lint:ignore:top_scope_facts
    Optional[String[1]]                     $auth_username           = undef,
    Optional[String[1]]                     $auth_password           = undef,
    Optional[String[1]]                     $useragent               = undef,
) {
    $use_tls = ($force_tls or $port == 443)
    $safe_title = $title.regsubst('\W', '_', 'G')
    $module_file = "/etc/prometheus/blackbox.yml.d/${safe_title}.yml"
    $alerts_file = "/srv/prometheus/ops/rules/alerts_${safe_title}.yaml"
    $target_file = '/srv/prometheus/ops/targets/probes-custom_puppet.yaml'
    $basic_auth = ($auth_username and $auth_password) ? {
        true    => { 'username' => $auth_username, 'password' => $auth_password },
        default => undef,
    }

    $headers = $useragent ? {
        undef   => { 'Host' => $fqdn },
        default => { 'Host' => $fqdn, 'User-Agent' => $useragent},
    }
    $client_auth_config = $use_client_auth ? {
        false   => {},
        default => {'cert_file' => $client_auth_cert, 'key_file' => $client_auth_key},
    }
    $tls_config = $use_tls ? {
        false   => {},
        default => {'server_name' => $fqdn} + $client_auth_config,
    }

    $http_module_params = {
        'headers'                         => $headers,
        'no_follow_redirects'             => !$follow_redirects,
        'method'                          => $method,
        # Needs at least Bullseye, https://phabricator.wikimedia.org/T309979
        # 'ip_protocol_fallback'          => false,
        'fail_if_ssl'                     => !$use_tls,
        'fail_if_not_ssl'                 => $use_tls,
        'tls_config'                      => $tls_config,
        'fail_if_body_matches_regexp'     => $body_regex_not_matches,
        'fail_if_body_not_matches_regexp' => $body_regex_matches,
        'fail_if_header_matches'          => $header_not_matches,
        'fail_if_header_not_matches'      => $header_matches,
        'basic_auth'                      => $basic_auth,
        'bearer_token'                    => $bearer_token,
        'body'                            => wmflib::encode_www_form($body),
    }.filter |$key, $value| { $value =~ Boolean or ($value =~ NotUndef and !$value.empty) }
    $module_config = {
        'modules' => Hash($ip_families.map |$family| {
            [ "http_${safe_title}_${family}",
              {
                  'prober' => 'http',
                  'timeout' => $timeout,
                  'http' => $http_module_params + { 'preferred_ip_protocol' => $family }
              }
            ]
        }),
    }
    $target_config = $ip_families.map |$family| {
        $proto = $use_tls.bool2str('https', 'http')
        $address = ($family == 'ip4').bool2str($ip4, $ip6)
        $data = {
            'labels' => {
                'address' => $address,
                'family'  => $family,
                'module'  => "http_${safe_title}_${family}",
            },
            'targets' => ["${target}:${port}@${proto}://[${address}]:${port}${path}"],
        }
        $data
    }
    $alert_config = {
        'groups' => [{
            'name'  => 'ssl_expire',
            'rules' => [{
                'alert'      => 'CertAlmostExpired',
                'expr'       => "probe_ssl_earliest_cert_expiry{module=~'http_${safe_title}_.*'} - time() < (${certificate_expiry_days} * 86400)",
                'for'         => '3h',
                'labels'      => {
                    'team'     => $team,
                    'severity' => $severity,
                },
                'annotations' => {
                    'description' => 'The certificate presented by service {{ $labels.instance }} is going to expire in {{ $value | humanizeDuration }}',
                    'summary'     => 'Certificate for service {{ $labels.instance }} is about to expire',
                    'dashboard'   => 'https://grafana.wikimedia.org/d/K1dRhGCnz/probes-tls-dashboard',
                    'runbook'     => 'https://wikitech.wikimedia.org/wiki/TLS/Runbook#{{ $labels.instance }}',
                },
            }],
        }],
    }
    $module_file_params = {
        'ensure'  => 'file',
        'content' => $module_config.wmflib::to_yaml,
        'notify'  => Exec['assemble blackbox.yml'],
        'tag'     => "prometheus::blackbox::check::http::${::site}::module",
    }
    $alert_file_params  = {
        'ensure'  => 'file',
        'content' => $alert_config.wmflib::to_yaml,
        'tag'     => "prometheus::blackbox::check::http::${::site}::alert",
    }
    $target_frag_params = {
        'ensure'  => 'file',
        'content' => $target_config.wmflib::to_yaml,
        'tag'     => "prometheus::blackbox::check::http::${::site}::target",
    }

    wmflib::resource::export('file', $module_file, $module_file_params)
    wmflib::resource::export('file', $alerts_file, $alert_file_params)
    wmflib::resource::export('file', $target_file, $target_frag_params)
}
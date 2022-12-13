# SPDX-License-Identifier: Apache-2.0
class profile::wmcs::services::toolsdb_replica_cnf(
    String $tool_replica_cnf_path = lookup('profile::wmcs::services::toolsdb_replica_cnf::tool_replica_cnf_path'),
    String $paws_replica_cnf_path = lookup('profile::wmcs::services::toolsdb_replica_cnf::paws_replica_cnf_path'),
    String $user_replica_cnf_path = lookup('profile::wmcs::services::toolsdb_replica_cnf::user_replica_cnf_path'),
    String $htuser                = lookup('profile::wmcs::services::toolsdb_replica_cnf::htuser'),
    String $htpassword            = lookup('profile::wmcs::services::toolsdb_replica_cnf::htpassword'),
    String $htpassword_salt       = lookup('profile::wmcs::services::toolsdb_replica_cnf::htpassword_salt'),
    String $tools_project_prefix  = lookup('profile::wmcs::services::toolsdb_replica_cnf::tools_project_prefix'),
) {

    $user                           = 'www-data'
    $group                          = 'www-data'
    $modules_uri                    = 'puppet:///modules/'
    $base_path                      = "/home/${user}"
    $api_service_base_path          = "${base_path}/replica_cnf_api_service"
    $api_service_app_path           = "${api_service_base_path}/replica_cnf_api_service"
    $api_service_base_path_in_repo  = "${modules_uri}profile/wmcs/nfs/replica_cnf_api_service"
    $api_service_app_path_in_repo   = "${api_service_base_path_in_repo}/replica_cnf_api_service"
    $replica_cnf_config_file_path   = '/etc/replica_cnf_config.yaml'
    $scripts_path                   = '/usr/local/bin'
    $write_replica_cnf_script_path  = "${scripts_path}/write_replica_cnf.sh"
    $read_replica_cnf_script_path   = "${scripts_path}/read_replica_cnf.sh"
    $delete_replica_cnf_script_path = "${scripts_path}/delete_replica_cnf.sh"
    $metrics_dir                    = '/run/toolsdb-replica-cnf-metrics'
    $htpassword_file                = '/etc/nginx/toolsdb-replica-cnf.htpasswd';
    $htpassword_hash                = htpasswd($htpassword, $htpassword_salt);

    package { 'flask':
        ensure   => installed,
        name     => 'Flask>=2.0.0,<2.1.0',
        provider => 'pip3',
    }

    file { $replica_cnf_config_file_path:
        ensure  => 'file',
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => to_yaml({
          'USE_SUDO'              => true,
          'TOOLS_PROJECT_PREFIX'  => $tools_project_prefix,
          'SCRIPTS_PATH'          => $scripts_path,
          'TOOL_REPLICA_CNF_PATH' => $tool_replica_cnf_path,
          'PAWS_REPLICA_CNF_PATH' => $paws_replica_cnf_path,
          'USER_REPLICA_CNF_PATH' => $user_replica_cnf_path,
        })
    }

    file { $write_replica_cnf_script_path:
        ensure => 'file',
        owner  => 'root',
        group  => 'root',
        mode   => '0500',
        source => "${api_service_base_path_in_repo}/write_replica_cnf.sh"
    }

    file { $read_replica_cnf_script_path:
        ensure => 'file',
        owner  => 'root',
        group  => 'root',
        mode   => '0500',
        source => "${api_service_base_path_in_repo}/read_replica_cnf.sh"
    }

    file { $delete_replica_cnf_script_path:
        ensure => 'file',
        owner  => 'root',
        group  => 'root',
        mode   => '0500',
        source => "${api_service_base_path_in_repo}/delete_replica_cnf.sh"
    }

    sudo::user { $user:
        ensure     => present,
        privileges => [
            "ALL = (ALL) NOPASSWD: ${write_replica_cnf_script_path}",
            "ALL = (ALL) NOPASSWD: ${read_replica_cnf_script_path}",
            "ALL = (ALL) NOPASSWD: ${delete_replica_cnf_script_path}",
        ]
    }


    file { [$base_path, $api_service_base_path]:
        ensure  => 'directory',
        owner   => $user,
        group   => $group,
        require => Sudo::User[ $user ],
        recurse => true,
        purge   => true
    }

    file { $api_service_app_path:
        ensure  => 'directory',
        owner   => $user,
        group   => $group,
        require => File[ $base_path, $api_service_base_path ],
        recurse => true,
        source  => $api_service_app_path_in_repo,
        }

    # ensure that auth files folders exist
    wmflib::dir::mkdir_p([
        $tool_replica_cnf_path,
        $paws_replica_cnf_path,
        $user_replica_cnf_path], {
            ensure => directory,
            owner => $user,
            group => $group
    })

    # Needed for prometheus exporter to share metrics between uwsgi processes
    file { $metrics_dir:
        ensure => 'directory',
        owner  => $user,
        group  => $group,
    }

    systemd::tmpfile { 'toolsdb-replica-cnf-shared-metrics':
        content => "d ${metrics_dir} 0755 ${user} ${group}",
    }

    uwsgi::app { 'toolsdb-replica-cnf-web':
        ensure             => 'present',
        subscribe          => [
            Package['flask'],
            File[ $api_service_base_path ],
            ],
        settings           => {
            uwsgi              => {
                'plugins'      => 'python3',
                'socket'       => '/run/uwsgi/toolsdb-replica-cnf-web.sock',
                'module'       => 'views:app',
                'chmod-socket' => 664,
                'die-on-term'  => true,
                'vacuum'       => true,
                'master'       => true,
                'processes'    => 8,
                'chdir'        => $api_service_app_path,
                'env'          => [
                    # fix prometheus exporter for multiple uwsgi processes/workers
                    "PROMETHEUS_MULTIPROC_DIR=${metrics_dir}",
                ],
            },
        },
        extra_systemd_opts => {
            'ExecStartPre' => [
                # Clear out metrics caches for previous runs
                "/bin/bash -c \"rm -rf ${metrics_dir}/*\"",
            ],
        },
    }

    file { $htpassword_file:
            content => "${htuser}:${htpassword_hash}",
            owner   => $user,
            group   => $group,
            mode    => '0440',
            before  => Service['nginx'],
            require => Package['nginx-common'],
    }

    nginx::site { 'toolsdb-replica-cnf-web-nginx':
        require => Uwsgi::App['toolsdb-replica-cnf-web'],
        content => template('profile/wmcs/nfs/toolsdb-replica-cnf-web.nginx.erb'),
    }


    ensure_packages(['bats'])
    file { '/srv/ops':
      ensure => 'directory',
      mode   => '0500',
    }
    file { '/srv/ops/replica_cnf_web':
      ensure => 'directory',
      mode   => '0500',
    }
    $func_tests_dir='/srv/ops/replica_cnf_web/functional_tests'
    $puppet_path='profile/wmcs/nfs/replica_cnf_web_fullstack_tests'
    file { $func_tests_dir:
      ensure => 'directory',
      mode   => '0500',
    }
    file { "${func_tests_dir}/helpers.bash":
      content => epp(
        "${puppet_path}/helpers.bash.epp",
        {
          'http_user'     => $htuser,
          'http_password' => $htpassword,
        }
      ),
      mode    => '0400',
    }
    file { "${func_tests_dir}/paws_account.bats":
      source => "puppet:///modules/${puppet_path}/paws_accounts.bats",
      mode   => '0400',
    }
    file { "${func_tests_dir}/user_account.bats":
      source => "puppet:///modules/${puppet_path}/user_accounts.bats",
      mode   => '0400',
    }
    file { "${func_tests_dir}/tool_account.bats":
      source => "puppet:///modules/${puppet_path}/tool_accounts.bats",
      mode   => '0400',
    }
}

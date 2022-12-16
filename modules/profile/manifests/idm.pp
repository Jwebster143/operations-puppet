# SPDX-License-Identifier: Apache-2.0

class profile::idm(
    Stdlib::Fqdn $service_fqdn              = lookup('profile::idm::service_fqdn'),
    String       $django_secret_key         = lookup('profile::idm::server::django_secret_key'),
    String       $django_mysql_db_host      = lookup('profile::idm::server::django_mysql_db_host'),
    String       $django_mysql_db_password  = lookup('profile::idm::server::django_mysql_db_password'),
    String       $django_mysql_db_user      = lookup('profile::idm::server::django_mysql_db_user', {'default_value' => 'idm'}),
    String       $django_mysql_db_name      = lookup('profile::idm::server::django_mysql_db_name', {'default_value' => 'idm'}),
    String       $deploy_user               = lookup('profile::idm::deploy_user', {'default_value'                  => 'www-data'}),
    Integer      $uwsgi_process_count       = lookup('profile::idm::uwsgi_process_count', {'default_value'          => 4}),
    Boolean      $development               = lookup('profile::idm::development',  {'default_value'                 => False}),
) {

    $base_dir = '/srv/idm'
    $media_dir = "${base_dir}/media"
    $static_dir = "${base_dir}/static"
    $project = 'bitu'
    $uwsgi_socket = "/run/uwsgi/${project}.sock"

    ferm::service { 'idm_http':
        proto => 'tcp',
        port  => 'http',
    }

    class { 'idm::deployment':
        project                  => $project,
        service_fqdn             => $service_fqdn,
        django_secret_key        => $django_secret_key,
        django_mysql_db_name     => $django_mysql_db_name,
        django_mysql_db_host     => $django_mysql_db_host,
        django_mysql_db_user     => $django_mysql_db_user,
        django_mysql_db_password => $django_mysql_db_password,
        base_dir                 => $base_dir,
        deploy_user              => $deploy_user,
        development              => $development,
    }

    class { 'idm::uwsgi_processes':
        project             => $project,
        base_dir            => $base_dir,
        uwsgi_process_count => $uwsgi_process_count,
        uwsgi_socket        => $uwsgi_socket,
    }

    class {'httpd':
        modules => ['proxy_http', 'proxy', 'proxy_uwsgi']
    }

    httpd::site { 'idm':
        ensure  => present,
        content => template('idm/idm-apache-config.erb'),
    }
}

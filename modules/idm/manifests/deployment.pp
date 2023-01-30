# SPDX-License-Identifier: Apache-2.0

class idm::deployment (
    String           $project,
    String           $service_fqdn,
    String           $django_secret_key,
    String           $django_mysql_db_host,
    String           $django_mysql_db_name,
    String           $django_mysql_db_user,
    String           $django_mysql_db_password,
    Stdlib::Unixpath $base_dir,
    String           $deploy_user,
    String           $etc_dir,
    String           $log_dir,
    Boolean          $production,
    Hash             $oidc,
    Hash             $ldap_config,
){
    # We need django from backports to get latest LTS.
    if debian::codename::eq('bullseye') {
        apt::pin { 'python3-django':
            pin      => 'release a=bullseye-backports',
            package  => 'python3-django',
            priority => 1001,
        }
    }

    # Django configuration
    file { "${etc_dir}/settings.py":
        ensure  => present,
        content => template('idm/idm-django-settings.erb'),
        owner   => $deploy_user,
        group   => $deploy_user,

    }

    # We need the base configuration from the Bitu
    # project. This contain non-secret settings that
    # are generic for all Bitu projects.
    file { "${etc_dir}/base_settings.py":
        ensure => link,
        target => "${base_dir}/${project}/bitu/base_settings.py"
    }

    # For staging and production we want to install
    # from Debian packages, but for the development
    # process the latest git version is deployed.
    if($production == false){
        ensure_packages(['python3-venv', 'redis',])

        $venv = "${base_dir}/venv"

        file { $base_dir :
            ensure => directory,
            owner  => $deploy_user,
            group  => $deploy_user,
        }

        git::clone { 'operations/software/bitu':
            ensure    => 'latest',
            directory => "${base_dir}/${project}",
            branch    => 'master',
            owner     => $deploy_user,
            group     => $deploy_user,
            source    => 'gerrit',
        }

        exec { "create virtual environment ${venv}":
            command => "/usr/bin/python3 -m venv ${venv}",
            creates => "${venv}/bin/activate",
        }

        exec { "install requirements to ${venv}":
            command => "${venv}/bin/pip3 install -r ${base_dir}/${project}/requirements.txt",
            creates => "${venv}/bin/django-admin",
            require => Exec["create virtual environment ${venv}"],
        }

        exec { 'collect static assets':
            command     => "${base_dir}/venv/bin/python ${base_dir}/${project}/manage.py collectstatic  --no-input",
            environment => ["PYTHONPATH=${etc_dir}", 'DJANGO_SETTINGS_MODULE=settings']
        }
    }

    $logs = ['idm', 'django']
    $logs.each |$log| {
        logrotate::rule { "bitu-${log}":
        ensure        => present,
        file_glob     => "${log_dir}/${log}.log",
        frequency     => 'daily',
        not_if_empty  => true,
        copy_truncate => true,
        max_age       => 30,
        rotate        => 30,
        date_ext      => true,
        compress      => true,
        missing_ok    => true,
        no_create     => true,
        }
    }
}

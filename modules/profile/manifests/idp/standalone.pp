# SPDX-LicensekIdentifier: Apache-2.0
# @summary Standalone IDP class for creating an instance in WM cloud
class profile::idp::standalone {
  ensure_packages(['python3-flask', 'python3-venv'])
  # Standard stuff
  include profile::base::production
  include profile::base::firewall

  # configure database
  include profile::mariadb::packages_wmf
  class { 'mariadb::service': }
  class { 'mariadb::config':
    basedir => '/usr',
    config  => 'role/mariadb/mysqld_config/misc.my.cnf.erb',
    datadir => '/srv/sqldata',
  }
  # TODO: configure openldap
  #  https://wikitech.wikimedia.org/wiki/Standalone-slapd

  # configure IDP
  include profile::idp
  include profile::java
  # Set up test web application
  $wsgi_file = '/srv/idp-test-login/wsgi.py'
  $venv_path = $wsgi_file.dirname

  file { $venv_path:
    ensure  => directory,
    recurse => remote,
    purge   => true,
    source  => 'puppet:///modules/profile/idp/standalone/idp_test_login',
  }
  exec { "create virtual environment ${venv_path}":
      command => "/usr/bin/python3 -m venv ${venv_path}",
      creates => "${venv_path}/bin/activate",
  }
  exec { "install requirements to ${venv_path}":
      command => "${venv_path}/bin/pip3 install -r ${venv_path}/requirements.txt",
      creates => "${venv_path}/lib/python3.9/site-packages/social_flask/__init__.py",
      require => Exec["create virtual environment ${venv_path}"],
  }
  uwsgi::app { 'idp-test':
    settings => {
      uwsgi => {
        'plugins'     => 'python3',
        'venv'        => $venv_path,
        'master'      => true,
        'http-socket' => '127.0.0.1:8081',
        'wsgi-file'   => $wsgi_file,
        'die-on-term' => true,
      },
    },
  }

  class { 'httpd': modules => ['proxy_http', 'proxy'] }
  include profile::idp::client::httpd
  ferm::service { 'http-idp-test-login':
    proto => 'tcp',
    port  => 80,
  }
}

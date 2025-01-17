# SPDX-License-Identifier: Apache-2.0
class profile::kerberos::kadminserver (
    Stdlib::Fqdn $krb_realm_name = lookup('kerberos_realm_name'),
    Stdlib::Fqdn $krb_kadmin_primary = lookup('kerberos_kadmin_server_primary'),
    Stdlib::Fqdn $krb_kadmin_keytabs_repo = lookup('kerberos_kadmin_keytabs_repo'),
    Array[String] $rsync_secrets_file_auth_users = lookup('profile::kerberos::kadminserver', { 'default_value' => ['kerb'] }),
    Optional[Boolean] $enable_replication = lookup('profile::kerberos::kadminserver::enable_replication', {'default_value' => false} ),
    Optional[Boolean] $monitoring_enabled = lookup('profile::kerberos::kadminserver::monitoring_enabled', { 'default_value' => false }),
) {
    package { 'krb5-admin-server':
        ensure => present,
    }

    package { 'python3-pexpect':
        ensure => present,
    }

    $is_krb_master = $facts['fqdn'] == $krb_kadmin_primary

    if $is_krb_master {
        $ensure_motd = 'absent'

        # The kadmin server shutsdown by itself if
        # not running on the master/primary node.
        service { 'krb5-admin-server':
            ensure  => running,
            require => Package['krb5-admin-server'],
        }
    } else {
        $ensure_motd = 'present'
    }

    motd::script { 'inactive_warning':
        ensure   => $ensure_motd,
        priority => 1,
        content  => template('profile/kerberos/kadminserver/inactive.motd.erb'),
    }

    ferm::service { 'kerberos_kpasswd_tcp':
        proto  => 'tcp',
        port   => '464',
        srange => '$DOMAIN_NETWORKS',
    }

    ferm::service { 'kerberos_kpasswd_udp':
        proto  => 'udp',
        port   => '464',
        srange => '$DOMAIN_NETWORKS',
    }

    # Util script to help generating keytabs
    file{ '/usr/local/sbin/generate_keytabs.py':
        ensure => file,
        mode   => '0550',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/profile/kerberos/generate_keytabs.py',
    }

    file{ '/usr/local/sbin/manage_principals.py':
        ensure => file,
        mode   => '0550',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/profile/kerberos/manage_principals.py',
    }

    # Keytabs will be generated manually, via a script that uses kadmin.local,
    # under /srv/kerberos/keytabs
    file{ '/srv/kerberos':
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    file{ '/srv/kerberos/keytabs':
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0750',
    }

    # Add the rsync server configuration only to the
    # active kerberos host.
    if $is_krb_master {
        $ensure_rsync = 'present'
        $ensure_rsync_secrets_file = 'present'
    } else {
        $ensure_rsync = 'absent'
        $ensure_rsync_secrets_file = 'absent'
    }

    if $is_krb_master {
        class { 'rsync::server': }
    }

    $rsync_secrets_file = '/srv/kerberos/rsync_secrets_file'
    file { $rsync_secrets_file:
        ensure    => $ensure_rsync_secrets_file,
        owner     => 'root',
        group     => 'root',
        mode      => '0400',
        content   => secret('kerberos/rsync_secrets_file'),
        show_diff => false,
        require   => File['/srv/kerberos']
    }

    rsync::server::module { 'srv-keytabs':
        ensure         => $ensure_rsync,
        path           => '/srv/kerberos/keytabs',
        read_only      => 'yes',
        hosts_allow    => [$krb_kadmin_keytabs_repo],
        auto_ferm      => true,
        auto_ferm_ipv6 => true,
        auth_users     => $rsync_secrets_file_auth_users,
        secrets_file   => $rsync_secrets_file,
        require        => File[$rsync_secrets_file],
    }

    if $enable_replication {
        include ::profile::kerberos::replication
    }

    if $monitoring_enabled and $is_krb_master {
        nrpe::monitor_service { 'krb-kadmin-server':
            description   => 'Kerberos KAdmin daemon',
            nrpe_command  => '/usr/lib/nagios/plugins/check_procs -c 1:1 -a "/usr/sbin/kadmind"',
            contact_group => 'admins,analytics',
            require       => Service['krb5-admin-server'],
            notes_url     => 'https://wikitech.wikimedia.org/wiki/Analytics/Systems/Kerberos#Daemons_and_their_roles',
        }
    }
}

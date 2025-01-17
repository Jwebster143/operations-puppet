class apt(
    Boolean $purge_sources           = false,
    Boolean $purge_preferences       = false,
    Boolean $use_proxy               = true,
    Boolean $manage_apt_source       = false,
    Boolean $install_audit_installed = false,
    String  $mirror                  = 'mirrors.wikimedia.org',
    Boolean $use_private_repo        = false,
) {
    $components =  $facts['is_virtual'] ? {
        true    => 'main',
        default => 'main thirdparty/hwraid',
    }

    exec { 'apt-get update':
        path        => '/usr/bin',
        timeout     => 240,
        returns     => [ 0, 100 ],
        refreshonly => true,
    }

    # Directory to hold the repository signing keys
    file { '/etc/apt/keyrings':
        ensure  => directory,
        mode    => '0755',
        recurse => true,
        purge   => true,
    }

    file { '/var/lib/apt/keys':
        ensure  => absent,
        recurse => true,
        purge   => true,
        force   => true,
    }

    # prefer Wikimedia APT repository packages in all cases
    apt::pin { 'wikimedia':
        package  => '*',
        pin      => 'release o=Wikimedia',
        priority => 1001,
    }

    if $manage_apt_source {

        # Starting with bookworm there's a new non-free-firmware component
        # Starting with bullseye, the security suite moved from
        #   foo/updates to foo-security (since the former was confusingly
        #   similar to foo-updates (what was called volatile.debian.org
        #   in the past)
        # Stretch has been removed, so the apt config only ships stub entries
        if debian::codename::eq('bullseye') {
            $apt_template    = 'apt/base-apt-conf-bullseye.erb'
        } elsif debian::codename::eq('bookworm') {
            $apt_template    = 'apt/base-apt-conf-bookworm.erb'
        } elsif debian::codename::eq('stretch') {
            $apt_template    = 'apt/base-apt-conf-stretch.erb'
        } elsif debian::codename::eq('buster') {
            $apt_template    = 'apt/base-apt-conf-buster.erb'
        }

        file { '/etc/apt/sources.list':
            ensure  => file,
            mode    => '0555',
            owner   => 'root',
            group   => 'root',
            content => template($apt_template),
            require => Apt::Repository['wikimedia'],
        }
    }

    file { '/etc/apt/sources.list.d':
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        recurse => $purge_sources,
        purge   => $purge_sources,
    }
    file { '/etc/apt/preferences.d':
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        recurse => $purge_preferences,
        purge   => $purge_preferences,
    }

    if $use_proxy {
        $http_proxy = "http://webproxy.${::site}.wmnet:8080"
        apt::conf { 'security-debian-proxy':
            ensure   => present,
            priority => '80',
            key      => 'Acquire::http::Proxy::security.debian.org',
            value    => $http_proxy,
            before   => File['/etc/apt/apt.conf'],
        }
        apt::conf { 'security-cdn-debian-proxy':
            ensure   => present,
            priority => '80',
            key      => 'Acquire::http::Proxy::security-cdn.debian.org',
            value    => $http_proxy,
            before   => File['/etc/apt/apt.conf']
        }
        apt::conf { 'deb-debian-org':
            ensure   => present,
            priority => '80',
            key      => 'Acquire::http::Proxy::deb.debian.org',
            value    => $http_proxy,
            before   => File['/etc/apt/apt.conf']
        }
    }

    # Starting with Bookworm the Debian installer defaults to using the signed-by
    # notation in apt-setup, also apply the same for the puppetised Wikimedia
    # repository.
    # The signed-by notation allows to specify which repository key is used
    # for which repository (previously they applied to all repos)
    # https://wiki.debian.org/DebianRepository/UseThirdParty
    if debian::codename::ge('bookworm'){
        $wikimedia_apt_keyfile = 'puppet:///modules/install_server/autoinstall/keyring/wikimedia-archive-keyring.gpg'
    } else {
        $wikimedia_apt_keyfile = undef
    }

    apt::repository { 'wikimedia':
        uri         => 'http://apt.wikimedia.org/wikimedia',
        dist        => "${::lsbdistcodename}-wikimedia",
        components  => $components,
        comment_old => true,
        keyfile     => $wikimedia_apt_keyfile,
    }

    if debian::codename::ge('bullseye') and $use_private_repo and !$facts['is_virtual']{
        $ensure_private_repo = present
    } else {
        $ensure_private_repo = absent
    }

    apt::repository { 'wikimedia-private':
        ensure     => $ensure_private_repo,
        uri        => 'http://apt.wikimedia.org:8080',
        dist       => "${::lsbdistcodename}-wikimedia-private",
        components => 'thirdparty/hwraid',
        keyfile    => $wikimedia_apt_keyfile,
    }

    if debian::codename::ge('buster'){
        apt::repository { 'debian-backports':
            uri         => 'http://mirrors.wikimedia.org/debian/',
            dist        => "${::lsbdistcodename}-backports",
            components  => 'main contrib non-free',
            comment_old => true,
        }
    }

    if debian::codename::ge('buster'){
        apt::repository { 'debian-debug':
            uri        => 'http://deb.debian.org/debian-debug',
            dist       => "${::lsbdistcodename}-debug",
            components => 'main contrib non-free',
            source     => false,
        }
    }

    apt::conf { 'InstallRecommends':
        ensure   => 'present',
        priority => '00',
        key      => 'APT::Install-Recommends',
        value    => false,
        before   => File['/etc/apt/apt.conf'],
    }

    if debian::codename::ge('buster') {
        apt::conf { 'apt-harden':
            ensure   => 'present',
            priority => '30',
            key      => 'APT::Sandbox::Seccomp',
            value    => true,
            before   => File['/etc/apt/apt.conf'],
        }
    }

    # This will munge /etc/apt/apt.conf that get's created during installation
    # process (either labs vmbuilder or d-i). Given the ones below exist, it is
    # no longer needed after the installation is over
    file { '/etc/apt/apt.conf':
        ensure => absent,
        notify => Exec['apt-get update'],
    }
    if $install_audit_installed {
        file {'/usr/local/sbin/apt-audit-installed':
            ensure => file,
            mode   => '0555',
            source => 'puppet:///modules/apt/apt_audit_installed.py',
        }
    }

    file { '/usr/local/sbin/dist-upgrade':
        ensure => file,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
        source => 'puppet:///modules/apt/dist-upgrade.sh',
    }
}

# === Define: nrpe::monitor_systemd_unit_state
#
# Installs a check for a systemd unit state using systemctl
define nrpe::monitor_systemd_unit_state(
    $unit = $title,
    $description = "${title} service",
    $contact_group = 'admins',
    $retries = 3,
    $timeout = 10,
    $critical = false,
    $ensure = 'present',
    $expected_state = 'active',
    $lastrun = '',
    Stdlib::Httpsurl $notes_url = 'https://wikitech.wikimedia.org/wiki/Monitoring/systemd_unit_state',
    $check_interval = 1,
    ){

    require nrpe::systemd_scripts

    # Temporary hack until we fix the downstream modules
    if $critical {
        $nagios_critical = true
    } else {
        $nagios_critical = false
    }

    nrpe::monitor_service { "${unit}-state":
        ensure         => $ensure,
        description    => $description,
        nrpe_command   => "/usr/local/lib/nagios/plugins/check_systemd_unit_state '${unit}' ${expected_state} ${lastrun}",
        contact_group  => $contact_group,
        retries        => $retries,
        timeout        => $timeout,
        critical       => $nagios_critical,
        notes_url      => $notes_url,
        check_interval => $check_interval,
    }
}

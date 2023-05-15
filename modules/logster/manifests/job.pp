# SPDX-License-Identifier: Apache-2.0
# == Define logster::job
# Installs a logster systemd timer
#
# == Parameters
# $parser            - Logster parser class name to use.
# $logfile           - Path to logfile to tail and report metrics about.
# $logster_options   - Full CLI option string to pass to logster.  Default: undef
#
# This class also configures the timer frequency:
# $minute (defaults to */5), $hour, $weekday, $month, $monthday.
# These are used for scheduling how often you want logster to parse the logfile
# and send metrics.
#
# NOTE: When defining job as 'absent', the package will become unmanaged
# and will need to be removed manually.
#
define logster::job(
    $parser,
    $logfile,
    $ensure          = 'present',
    $logster_options = undef,
    $minute          = '0/5',
    $hour            = '*',
    $month           = '*',
    $monthday        = '*',
) {

    if ($ensure == 'present') {
        require ::logster
    }

    $interval = "*-${month}-${monthday} ${hour}:${minute}:00"

    $cmd_script = "/usr/local/sbin/logster-${title}-service.sh"
    file { $cmd_script:
        ensure  => stdlib::ensure($ensure, 'file'),
        content => "#!/bin/bash\n/usr/bin/logster ${logster_options} ${parser} ${logfile}\n",
        mode    => '0555',
    }

    systemd::timer::job { "logster-${title}":
        ensure      => $ensure,
        description => 'Generate metrics from logs',
        command     => $cmd_script,
        user        => 'root',
        interval    => {'start' => 'OnCalendar', 'interval' => $interval},
    }
}

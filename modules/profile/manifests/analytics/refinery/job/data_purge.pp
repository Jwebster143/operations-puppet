# == Class profile::analytics::refinery::job::data_purge
#
# Installs systemd-timer jobs to drop old hive partitions,
# delete old data from HDFS and sanitize EventLogging data.
#
# [*deploy_jobs*]
#   Temporary flag to avoid deploying jobs on new hosts.
#   Default: true
#
class profile::analytics::refinery::job::data_purge (
    Optional[String] $public_druid_host = lookup('profile::analytics::refinery::job::data_purge::public_druid_host', { 'default_value' => undef }),
    Wmflib::Ensure $ensure_timers       = lookup('profile::analytics::refinery::job::data_purge::ensure_timers', { 'default_value' => 'present' }),
    Boolean $use_kerberos_keytab        = lookup('profile::analytics::refinery::job::data_purge::use_kerberos_keytab', { 'default_value' => true }),
) {
    require ::profile::analytics::refinery

    $query_clicks_log_file           = "${profile::analytics::refinery::log_dir}/drop-query-clicks.log"
    $public_druid_snapshots_log_file = "${profile::analytics::refinery::log_dir}/drop-druid-public-snapshots.log"
    $mediawiki_dumps_log_file        = "${profile::analytics::refinery::log_dir}/drop-mediawiki-dumps.log"
    $el_unsanitized_log_file         = "${profile::analytics::refinery::log_dir}/drop-el-unsanitized-events.log"

    # Shortcut to refinery path
    $refinery_path = $profile::analytics::refinery::path

    # Shortcut var to DRY up commands.
    $env = "export PYTHONPATH=\${PYTHONPATH}:${refinery_path}/python"
    $systemd_env = {
        'PYTHONPATH' => "\${PYTHONPATH}:${refinery_path}/python",
    }

    # Send an email to analytics in case of failure
    $mail_to = 'analytics-alerts@wikimedia.org'

    # Keep this many days of raw webrequest data.
    $raw_retention_days = 31
    kerberos::systemd_timer { 'refinery-drop-webrequest-raw-partitions':
        ensure      => $ensure_timers,
        description => 'Drop Webrequest raw data imported on HDFS following data retention policies.',
        command     => "${refinery_path}/bin/refinery-drop-older-than --database='wmf_raw' --tables='webrequest' --base-path='/wmf/data/raw/webrequest' --path-format='.+/hourly/(?P<year>[0-9]+)(/(?P<month>[0-9]+)(/(?P<day>[0-9]+)(/(?P<hour>[0-9]+))?)?)?' --older-than='${raw_retention_days}' --skip-trash --execute='96726ec893174544fc9bd7c7fa0083ea'",
        interval    => '*-*-* 00/4:15:00',
        environment => $systemd_env,
        user        => 'analytics',
    }

    # Keep this many days of refined webrequest data.
    $refined_retention_days = 90
    kerberos::systemd_timer { 'refinery-drop-webrequest-refined-partitions':
        ensure      => $ensure_timers,
        description => 'Drop Webrequest refined data imported on HDFS following data retention policies.',
        command     => "${refinery_path}/bin/refinery-drop-older-than --database='wmf' --tables='webrequest' --base-path='/wmf/data/wmf/webrequest' --path-format='.+/year=(?P<year>[0-9]+)(/month=(?P<month>[0-9]+)(/day=(?P<day>[0-9]+)(/hour=(?P<hour>[0-9]+))?)?)?' --older-than='${refined_retention_days}' --skip-trash --execute='cf16215b8158e765b623db7b3f345d36'",
        interval    => '*-*-* 00/4:45:00',
        environment => $systemd_env,
        user        => 'analytics',
    }

    # Keep this many days of webrequest sequence stats data (400 days =~ 13 months) .
    $webrequest_sequence_stats_retention_days = 400
    kerberos::systemd_timer { 'refinery-drop-webrequest-sequence-stats-partitions':
        ensure      => $ensure_timers,
        description => 'Drop Webrequest sequence stats (detailed and hourly) from HDFS to prevent small-files number to grow.',
        command     => "${refinery_path}/bin/refinery-drop-older-than --database='wmf_raw' --tables='^webrequest_sequence_stats(_hourly)?$' --base-path='/user/hive/warehouse/wmf_raw.db' --path-format='webrequest_sequence_stats(_hourly)?/webrequest_source=[a-z]+/year=(?P<year>[0-9]+)(/month=(?P<month>[0-9]+)(/day=(?P<day>[0-9]+)(/hour=(?P<hour>[0-9]+))?)?)?' --older-than='${webrequest_sequence_stats_retention_days}' --skip-trash --execute='0b38d1307add57841c6726082fb04cd7'",
        interval    => '*-*-* 00:30:00',
        environment => $systemd_env,
        user        => 'analytics',
    }

    # Keep this many days of pageview_actor_hourly data.
    kerberos::systemd_timer { 'refinery-drop-pageview-actor-hourly-partitions':
        ensure      => $ensure_timers,
        description => 'Drop pageview_actor_hourly data from HDFS following data retention policies.',
        command     => "${refinery_path}/bin/refinery-drop-older-than --database='wmf' --tables='pageview_actor' --base-path='/wmf/data/wmf/pageview/actor' --path-format='year=(?P<year>[0-9]+)(/month=(?P<month>[0-9]+)(/day=(?P<day>[0-9]+)(/hour=(?P<hour>[0-9]+))?)?)?' --older-than='${refined_retention_days}' --skip-trash --execute='da789e9fea7e42f2f9db1d28c508321e'",
        interval    => '*-*-* 00/4:50:00',
        environment => $systemd_env,
        user        => 'analytics',
    }

    # Keep this many days of raw event data (all data that comes via EventGate instances).
    $event_raw_retention_days = 90
    kerberos::systemd_timer { 'refinery-drop-raw-event':
        ensure      => $ensure_timers,
        description => 'Drop raw event (/wmf/data/raw/event) data imported on HDFS following data retention policies.',
        command     => "${refinery_path}/bin/refinery-drop-older-than --base-path='/wmf/data/raw/event' --path-format='.+/hourly/(?P<year>[0-9]+)(/(?P<month>[0-9]+)(/(?P<day>[0-9]+)(/(?P<hour>[0-9]+))?)?)?' --older-than='${event_raw_retention_days}' --skip-trash --execute='209837413aff8d4332104e7dc454a27d'",
        interval    => '*-*-* 00/4:20:00',
        environment => $systemd_env,
        user        => 'analytics',
    }

    # mediawiki_job events are imported separately from regular events, so they need their own purge job.
    kerberos::systemd_timer { 'refinery-drop-raw-mediawiki-job-event':
        ensure      => $ensure_timers,
        description => 'Drop raw mediawiki job event (/wmf/data/raw/mediawiki_job) data imported on HDFS following data retention policies.',
        command     => "${refinery_path}/bin/refinery-drop-older-than --base-path='/wmf/data/raw/mediawiki_job' --path-format='[^/]+/hourly/(?P<year>[0-9]+)(/(?P<month>[0-9]+)(/(?P<day>[0-9]+)(/(?P<hour>[0-9]+))?)?)?' --older-than='${event_raw_retention_days}' --skip-trash --execute='23ee7ee56c3b87b6f0b971d6fb29425f'",
        interval    => '*-*-* 00/4:30:00',
        environment => $systemd_env,
        user        => 'analytics',
    }
    # netflow events are imported separately from regular events, so they need their own purge job.
    kerberos::systemd_timer { 'refinery-drop-raw-netflow-event':
        ensure      => $ensure_timers,
        description => 'Drop raw netflow event (/wmf/data/raw/netflow) data imported on HDFS following data retention policies.',
        command     => "${refinery_path}/bin/refinery-drop-older-than --base-path='/wmf/data/raw/netflow' --path-format='[^/]+/hourly/(?P<year>[0-9]+)(/(?P<month>[0-9]+)(/(?P<day>[0-9]+)(/(?P<hour>[0-9]+))?)?)?' --older-than='${event_raw_retention_days}' --skip-trash --execute='8be45ca349b01f84fde8b5481b85094c'",
        interval    => '*-*-* 00/4:35:00',
        environment => $systemd_env,
        user        => 'analytics',
    }


    # Keep this many days of refined event data (all data that comes via EventGate instances).
    $event_refined_retention_days = 90
    # Most (non EventLogging legacy) event data does not contain PII, so we keep it indefinetly.
    # Only tables with PII must be purged after $event_refined_retention_days.
    #
    # Maps dataset (table + base path in /wmf/data/event/$table) to the refinery-drop-older-than
    # --execute checksum to use.  A refinery-drop-refined-event job will be declared for
    # each entry in this hash.
    #
    $event_refined_to_drop = {
        'mediawiki_api_request'          => 'e06eaf4f3c6894fe7b943d9b40f83ace',
        'mediawiki_cirrussearch_request' => 'e93b86033b2025f8a793c8b170e6474f',
        'wdqs_external_sparql_query'     => 'f32f99c8fa41b56782bf22e1866cd79b',
        'wdqs_internal_sparql_query'     => '15f545ef0fe0ba8573c568ded41fb6e3',
    }

    # Since we are only dropping very specific event data, we don't want to use
    # refinery-drop-older-than with a --base-path of /wmf/data/event.
    # Doing so would cause it to hdfs dfs -ls glob EVERY event dataset path and then
    # prune the results for directories to drop.  By separating each dataset drop
    # into an individual job and using a --base-path specific to that dataset's LOCATION path,
    # we avoid having to ls glob and parse all other event dataset paths.
    #
    # NOTE: The tables parameter uses a double $$ sign. Systemd will transform this into a single $ sign.
    # So, if you want to make changes to this job, make sure to execute all tests (DRY-RUN) with just 1
    # single $ sign, to get the correct checksum. And then add the double $$ sign here.
    # Also, we need the systemd to escape our \w, AND we need puppet to do the same.  So we use
    # \\\\w to result in \\w in systemd which then ends up executing with a \w.  DRY-RUN with just
    # \w to get the proper checksum.
    $event_refined_to_drop.each |String $dataset, String $checksum| {
        kerberos::systemd_timer { "refinery-drop-refined-event.${dataset}":
            ensure      => $ensure_timers,
            description => "Drop refined event.${dataset} data imported on Hive/HDFS following data retention policies.",
            command     => "${refinery_path}/bin/refinery-drop-older-than --database='event' --tables='^${dataset}$$' --base-path='/wmf/data/event/${dataset}' --path-format='datacenter=\\\\w+(/year=(?P<year>[0-9]+)(/month=(?P<month>[0-9]+)(/day=(?P<day>[0-9]+)(/hour=(?P<hour>[0-9]+))?)?)?)?' --older-than='90' --skip-trash --execute='${checksum}'",
            interval    => '*-*-* 00:00:00',
            environment => $systemd_env,
            user        => 'analytics',
        }
    }

    # Keep this many days of raw eventlogging data.
    $eventlogging_retention_days = 90
    kerberos::systemd_timer { 'refinery-drop-eventlogging-partitions':
        ensure      => $ensure_timers,
        description => 'Drop Eventlogging data imported on HDFS following data retention policies.',
        command     => "${refinery_path}/bin/refinery-drop-older-than --base-path='/wmf/data/raw/eventlogging' --path-format='.+/hourly/(?P<year>[0-9]+)(/(?P<month>[0-9]+)(/(?P<day>[0-9]+)(/(?P<hour>[0-9]+))?)?)?' --older-than='${eventlogging_retention_days}' --skip-trash --execute='bb7022b36bcf0d75bdd03b6f836f09e6'",
        interval    => '*-*-* 00/4:15:00',
        environment => $systemd_env,
        user        => 'analytics',
    }

    kerberos::systemd_timer { 'refinery-drop-eventlogging-client-side-partitions':
        ensure      => $ensure_timers,
        description => 'Drop Eventlogging Client Side data imported on HDFS following data retention policies.',
        command     => "${refinery_path}/bin/refinery-drop-older-than --base-path='/wmf/data/raw/eventlogging_client_side' --path-format='eventlogging-client-side/hourly/(?P<year>[0-9]+)(/(?P<month>[0-9]+)(/(?P<day>[0-9]+)(/(?P<hour>[0-9]+))?)?)?' --older-than='${eventlogging_retention_days}' --skip-trash --execute='1fcad629ec569645ff864686e523029d'",
        interval    => '*-*-* 00/4:30:00',
        environment => $systemd_env,
        user        => 'analytics',
    }

    # keep this many days of druid webrequest sampled
    # Currently being tested as systemd timer, see below
    $druid_webrequest_sampled_retention_days = 60
    kerberos::systemd_timer { 'refinery-drop-webrequest-sampled-druid':
        ensure      => $ensure_timers,
        description => 'Drop Druid Webrequest sampled data from deep storage following data retention policies.',
        command     => "${refinery_path}/bin/refinery-drop-druid-deep-storage-data -d ${druid_webrequest_sampled_retention_days} webrequest_sampled_128",
        interval    => '*-*-* 05:15:00',
        environment => $systemd_env,
        user        => 'analytics',
    }

    # keep this many public druid mediawiki history refined snapshots
    # runs once a month
    if $public_druid_host {
        $druid_public_keep_snapshots = 3
        $mediawiki_history_reduced_basename = 'mediawiki_history_reduced'
        kerberos::systemd_timer { 'refinery-druid-drop-public-snapshots':
            ensure      => $ensure_timers,
            description => 'Drop Druid Public snapshots from deep storage following data retention policies.',
            command     => "${refinery_path}/bin/refinery-drop-druid-snapshots -d ${mediawiki_history_reduced_basename} -t ${public_druid_host} -s ${druid_public_keep_snapshots} -f ${public_druid_snapshots_log_file}",
            environment => $systemd_env,
            interval    => 'Mon,Tue,Wed,Thu,Fri *-*-15 09:00:00',
            user        => 'analytics',
        }
    }

    # Purge snapshots keeping only last 6 (except wmf.mediawiki_wikitext_history, keeping 2):
    #  wmf_raw.mediawiki_archive
    #  wmf_raw.mediawiki_change_tag
    #  wmf_raw.mediawiki_ipblocks
    #  wmf_raw.mediawiki_logging
    #  wmf_raw.mediawiki_page
    #  wmf_raw.mediawiki_pagelinks
    #  wmf_raw.mediawiki_project_namespace_map
    #  wmf_raw.mediawiki_redirect
    #  wmf_raw.mediawiki_revision
    #  wmf_raw.mediawiki_user
    #  wmf_raw.mediaiki_user_groups
    #
    #  wmf.mediawiki_history
    #  wmf.mediawiki_metrics
    #  wmf.mediawiki_page_history
    #  wmf.mediawiki_user_history
    #  wmf.mediawiki_history_reduced
    #  wmf.edit_hourly
    #  wmf.mediawiki_wikitext_history
    #  wmf.mediawiki_wikitext_current
    #  wmf.wikidata_entity
    #  wmf.wikidata_item_page_link
    #
    # runs twice a month on the 15th and 30th
    # (30th is to drop wikitext fast as it gets released at the end of the month)
    kerberos::systemd_timer { 'mediawiki-history-drop-snapshot':
        ensure      => $ensure_timers,
        description => 'Drop snapshots from multiple raw and refined mediawiki datasets, configured in the refinery-drop script.',
        command     => "${refinery_path}/bin/refinery-drop-mediawiki-snapshots",
        environment => $systemd_env,
        interval    => '*-*-15,30 06:15:00',
        user        => 'analytics',
    }

    # Delete mediawiki history dump snapshots older than 6 months.
    # Runs on the first day of each month. This way it frees up space for the new snapshot.
    $mediawiki_history_dumps_retention_days = 180
    kerberos::systemd_timer { 'refinery-drop-mediawiki-history-dumps':
        ensure      => $ensure_timers,
        description => 'Drop mediawiki history dump versions older than 6 months.',
        command     => "${refinery_path}/bin/refinery-drop-older-than --base-path='/wmf/data/archive/mediawiki/history' --path-format='(?P<year>[0-9]+)-(?P<month>[0-9]+)' --older-than='${mediawiki_history_dumps_retention_days}' --skip-trash --execute='40f24e7bbccb397671dfa3266c5ebd2f'",
        interval    => '*-*-01 00:00:00',
        environment => $systemd_env,
        user        => 'analytics',
    }

    # keep this many days of banner activity success files
    # runs once a day
    $banner_activity_retention_days = 90
    kerberos::systemd_timer { 'refinery-drop-banner-activity':
        ensure      => $ensure_timers,
        description => 'Clean old Banner Activity _SUCCESS flags from HDFS.',
        command     => "${refinery_path}/bin/refinery-drop-older-than --base-path='/wmf/data/wmf/banner_activity' --path-format='daily/year=(?P<year>[0-9]+)(/month=(?P<month>[0-9]+)(/day=(?P<day>[0-9]+))?)?' --older-than='${banner_activity_retention_days}' --skip-trash --execute='39b7f84330a54c2128f6ade41feba28b'",
        environment => $systemd_env,
        interval    => '*-*-* 02:00:00',
        user        => 'analytics',
    }

    # Drop unsanitized EventLogging data from the event database after retention period.
    # Runs once a day.
    # NOTE: The regexes here don't include underscores '_' when matching table names or directory paths.
    # No EventLogging (legacy) generated datasets have underscores, while all EventGate generated datasets do.
    # This implicitly excludes non EventLogging (legacy) datasets from being deleted.
    # Some EventGate datasets do need to be deleted.  This is done above by the refinery-drop-event job.
    # NOTE: The tables parameter uses a double $$ sign. Systemd will transform this into a single $ sign.
    # So, if you want to make changes to this job, make sure to execute all tests (DRY-RUN) with just 1
    # single $ sign, to get the correct checksum. And then add the double $$ sign here.
    kerberos::systemd_timer { 'drop-el-unsanitized-events':
        ensure      => $ensure_timers,
        description => 'Drop unsanitized EventLogging data from the event database after retention period.',
        command     => "${refinery_path}/bin/refinery-drop-older-than --database='event' --tables='.*' --base-path='/wmf/data/event' --path-format='[^/]+(/datacenter=[^/]+)?/year=(?P<year>[0-9]+)(/month=(?P<month>[0-9]+)(/day=(?P<day>[0-9]+)(/hour=(?P<hour>[0-9]+))?)?)?' --older-than='90' --execute='ea43326f56fd374d895bb931dc0ce3d4' --log-file='${el_unsanitized_log_file}'",
        interval    => '*-*-* 00:00:00',
        environment => $systemd_env,
        user        => 'analytics',
    }

    # drop data older than 2-3 months from cu_changes table, which is sqooped in
    # runs once a day (but only will delete data on the needed date)
    $geoeditors_private_retention_days = 60
    kerberos::systemd_timer { 'mediawiki-raw-cu-changes-drop-month':
        ensure      => $ensure_timers,
        description => 'Drop raw MediaWiki cu_changes from Hive/HDFS following data retention policies.',
        command     => "${refinery_path}/bin/refinery-drop-older-than --database='wmf_raw' --tables='mediawiki_private_cu_changes' --base-path='/wmf/data/raw/mediawiki_private/tables/cu_changes' --path-format='month=(?P<year>[0-9]+)-(?P<month>[0-9]+)' --older-than='${geoeditors_private_retention_days}' --skip-trash --execute='9d9f8adf2eb7de69c9c3634e45e1f7d9'",
        environment => $systemd_env,
        interval    => '*-*-* 05:00:00',
        user        => 'analytics',
    }

    # drop data older than 2-3 months from geoeditors_daily table
    # runs once a day (but only will delete data on the needed date)
    # Temporary stopped to prevent data to be dropped.
    kerberos::systemd_timer { 'mediawiki-geoeditors-drop-month':
        ensure      => $ensure_timers,
        description => 'Drop Geo-editors data from Hive/HDFS following data retention policies.',
        command     => "${refinery_path}/bin/refinery-drop-older-than --database='wmf' --tables='geoeditors_daily' --base-path='/wmf/data/wmf/mediawiki_private/geoeditors_daily' --path-format='month=(?P<year>[0-9]+)-(?P<month>[0-9]+)' --older-than='${geoeditors_private_retention_days}' --skip-trash --execute='5faa519abce3840e7718cfbde8779078'",
        environment => $systemd_env,
        interval    => '*-*-* 06:00:00',
        user        => 'analytics',
    }

    # drop monthly pages_meta_history dumps data after 80 days (last day of month as reference)
    # runs once a month
    $dumps_retention_days = 80
    kerberos::systemd_timer { 'drop-mediawiki-pages_meta_history-dumps':
        ensure      => $ensure_timers,
        description => 'Drop pages_meta_history dumps data from HDFS after 80 days.',
        command     => "${refinery_path}/bin/refinery-drop-older-than --base-path /wmf/data/raw/mediawiki/dumps/pages_meta_history --path-format '(?P<year>[0-9]{4})(?P<month>[0-9]{2})01' --older-than ${dumps_retention_days} --log-file ${mediawiki_dumps_log_file} --skip-trash --execute 88d1df6aee62b8562ab3d31964ba6b49",
        environment => $systemd_env,
        interval    => '*-*-20 06:00:00',
        user        => 'analytics',
    }

    # drop monthly pages_meta_current dumps data after 80 days (last day of month as reference)
    # runs once a month
    kerberos::systemd_timer { 'drop-mediawiki-pages_meta_current-dumps':
        ensure      => $ensure_timers,
        description => 'Drop pages_meta_current dumps data from HDFS after 80 days.',
        command     => "${refinery_path}/bin/refinery-drop-older-than --base-path /wmf/data/raw/mediawiki/dumps/pages_meta_current --path-format '(?P<year>[0-9]{4})(?P<month>[0-9]{2})01' --older-than ${dumps_retention_days} --log-file ${mediawiki_dumps_log_file} --skip-trash --execute 7fd55f34e12cb3a6c586a29043ae5402",
        environment => $systemd_env,
        interval    => '*-*-20 07:00:00',
        user        => 'analytics',
    }

    # drop monthly siteinfo_namespaces dumps data after 80 days (last day of month as reference)
    # runs once a month
    kerberos::systemd_timer { 'drop-mediawiki-siteinfo_namespaces-dumps':
        ensure      => $ensure_timers,
        description => 'Drop pages_meta_current dumps data from HDFS after 80 days.',
        command     => "${refinery_path}/bin/refinery-drop-older-than --base-path /wmf/data/raw/mediawiki/dumps/siteinfo_namespaces --path-format '(?P<year>[0-9]{4})(?P<month>[0-9]{2})01' --older-than ${dumps_retention_days} --log-file ${mediawiki_dumps_log_file} --skip-trash --execute b5ced2ce9e4be85f144a2228ade9125d",
        environment => $systemd_env,
        interval    => '*-*-20 05:00:00',
        user        => 'analytics',
    }

    # drop hourly pageview-actors data (3 datasets) used to compute automated agent-type after 90 days
    kerberos::systemd_timer { 'drop-features-actor-hourly':
        ensure      => $ensure_timers,
        description => 'Drop features.actor_hourly data from Hive and HDFS after 90 days.',
        command     => "${refinery_path}/bin/refinery-drop-older-than --database='features' --tables='actor_hourly' --base-path='/wmf/data/learning/features/actor/hourly' --path-format='year=(?P<year>[0-9]+)(/month=(?P<month>[0-9]+)(/day=(?P<day>[0-9]+)(/hour=(?P<hour>[0-9]+))?)?)?' --older-than='90' --skip-trash --execute='ef89b092947eb2f203ed01954e2b2d0b'",
        environment => $systemd_env,
        interval    => '*-*-* 00/4:40:00',
        user        => 'analytics',
    }
    kerberos::systemd_timer { 'drop-features-actor-rollup-hourly':
        ensure      => $ensure_timers,
        description => 'Drop features.actor_rollup_hourly data from Hive and HDFS after 90 days.',
        command     => "${refinery_path}/bin/refinery-drop-older-than --database='features' --tables='actor_rollup_hourly' --base-path='/wmf/data/learning/features/actor/rollup/hourly' --path-format='year=(?P<year>[0-9]+)(/month=(?P<month>[0-9]+)(/day=(?P<day>[0-9]+)(/hour=(?P<hour>[0-9]+))?)?)?' --older-than='90' --skip-trash --execute='bf6a6e00d03fbd7a4b57f778ff0fa35b'",
        environment => $systemd_env,
        interval    => '*-*-* 00/4:45:00',
        user        => 'analytics',
    }
    kerberos::systemd_timer { 'drop-predictions-actor_label-hourly':
        ensure      => $ensure_timers,
        description => 'Drop predictions.actor_label_hourly data from Hive and HDFS after 90 days.',
        command     => "${refinery_path}/bin/refinery-drop-older-than --database='predictions' --tables='actor_label_hourly' --base-path='/wmf/data/learning/predictions/actor/hourly' --path-format='year=(?P<year>[0-9]+)(/month=(?P<month>[0-9]+)(/day=(?P<day>[0-9]+)(/hour=(?P<hour>[0-9]+))?)?)?' --older-than='90' --skip-trash --execute='ad7bb119301815c3a17a2948ebbbf75a'",
        environment => $systemd_env,
        interval    => '*-*-* 00/4:50:00',
        user        => 'analytics',
    }
}

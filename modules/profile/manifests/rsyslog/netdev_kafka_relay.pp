# Class profile::rsyslog::netdev_kafka_relay - UDP syslog compatiblity endpoint for network devices

# This provides an entry point into the kafka logging pipeline for network hardware devices which do
# not have native support for kafka or rsyslog.
#
# Syslogs that arrive on $port are relayed to the kafka logging pipeline for durability and
# consumption by logtash

class profile::rsyslog::netdev_kafka_relay (
    Array   $logging_kafka_brokers = hiera('profile::rsyslog::kafka_shipper::kafka_brokers'),
    Integer $port = hiera('profile::rsyslog::netdev_kafka_relay_port', 10514),
    Array[String] $queue_enabled_sites = lookup('profile::rsyslog::kafka_queue_enabled_sites',
                                                {'default_value' => []}),
) {
    require_package('rsyslog-kafka')

    $queue_size = $::site in $queue_enabled_sites ? {
        true  => 10000,
        false => 0,
    }

    rsyslog::conf { 'netdev_kafka_relay':
        content  => template('profile/rsyslog/netdev_kafka_relay.conf.erb'),
        priority => 50,
    }

}

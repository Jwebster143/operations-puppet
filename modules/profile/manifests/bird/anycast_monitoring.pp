# SPDX-License-Identifier: Apache-2.0
# Define monitoring for all Anycast VIPs
# By their nature, those VIPs are advertized from several locations on the
# network. In its current state, Icinga can only alert if that IP is nowhere
# to be seen on the network. Not if the number of hosts advertizing that VIP
# falls under a certain threshold.
# The service check will only check the health of the server closest to Icinga
# in term of BGP distance (or multiple servers if load-balancing is enabled).

class profile::bird::anycast_monitoring{

    # Anycast recdns: Note use of the raw IP in the host title and ip_address -
    # otherwise the checks end up using local DNS lookups on icinga itself to
    # find the address of the DNS server being tested, which makes the process
    # and the results confusing and/or wrong.
    # For non-DNS anycast services we can probably use the real hostname and
    # host_fqdn instead, so please don't copypasta this for the next entry!

    monitoring::host { '10.3.0.1':
        ip_address => '10.3.0.1',
        critical   => true, # Page
    }

    monitoring::service { 'Recursive DNS anycast VIP':
        host          => '10.3.0.1',
        description   => 'recursive DNS anycast VIP',
        check_command => 'check_dns!www.wikipedia.org',
        notes_url     => 'https://wikitech.wikimedia.org/wiki/Anycast_recursive_DNS#Troubleshooting',
        critical      => true, # Page
    }

    monitoring::host { 'syslog.anycast.wmnet':
        host_fqdn => 'syslog.anycast.wmnet',
    }

    # Wikidough.
    monitoring::host { '185.71.138.138':
        ip_address => '185.71.138.138',
    }

    monitoring::service { 'check_wikidough_doh':
        host          => '185.71.138.138',
        description   => 'Wikidough DoH Check',
        check_command => 'check_https_url_custom_ip!wikimedia-dns.org!185.71.138.138!/',
        notes_url     => 'https://wikitech.wikimedia.org/wiki/Wikidough',
    }

    monitoring::service { 'check_wikidough_dot':
        host          => '185.71.138.138',
        description   => 'Wikidough DoT Check',
        check_command => 'check_tcp_ssl!185.71.138.138!853',
        notes_url     => 'https://wikitech.wikimedia.org/wiki/Wikidough',
    }

    # Wikidough durum.
    monitoring::host { 'check.wikimedia-dns.org':
        host_fqdn => 'check.wikimedia-dns.org',
    }
}

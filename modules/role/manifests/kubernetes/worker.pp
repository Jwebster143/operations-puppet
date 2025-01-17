class role::kubernetes::worker {
    include profile::base::production
    include profile::base::firewall

    # Sets up docker on the machine
    include profile::docker::engine
    # Setup dfdaemon and configure docker to use it
    include profile::dragonfly::dfdaemon
    # Setup kubernetes stuff
    include profile::kubernetes::node
    # Set up mediawiki-related stuff
    include profile::kubernetes::mediawiki_runner
    # Setup calico
    include profile::calico::kubernetes
    # Setup LVS
    include profile::lvs::realserver

    system::role { 'kubernetes::worker':
        description => 'Kubernetes worker node',
    }
}

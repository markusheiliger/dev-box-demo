#!/bin/bash

FORWARDERS=()
CLIENTS=()

while getopts 'f:s:' OPT; do
    case "$OPT" in
		f)
			FORWARDERS+=("${OPTARG}") ;;
		c)
			CLIENTS+=("${OPTARG}") ;;
    esac
done

# install required packages
sudo apt-get install -y --no-install-recommends bind9

# update bind configuration
sudo cat > /etc/bind/named.conf.options << EOF
acl goodclients {
    $2;
    localhost;
    localnets;
};
options {
	directory "/var/cache/bind";
	recursion yes;
	allow-query { goodclients; };
	forwarders {
		$1;
	};
	forward only;
	dnssec-validation no; 	# needed for private dns zones
	auth-nxdomain no;    	# conform to RFC1035
	listen-on { any; };
};
EOF

# restart bind with new config
sudo service bind9 restart
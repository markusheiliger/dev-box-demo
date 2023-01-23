#!/bin/bash

FORWARDERS=()
CLIENTS=()

while getopts 'f:c:' OPT; do
    case "$OPT" in
		f)
			FORWARDERS+=("${OPTARG}") ;;
		c)
			CLIENTS+=("${OPTARG}") ;;
    esac
done

# install required packages
sudo apt-get install -y bind9

FORWARDERS_VALUE=$(printf "%s;\n" "${FORWARDERS[@]}")
CLIENTS_VALUE=$(printf "%s;\n" "${CLIENTS[@]}")

# update bind configuration
sudo cat > /etc/bind/named.conf.options << EOF
acl goodclients {
    $CLIENTS_VALUE;
    localhost;
    localnets;
};
options {
	directory "/var/cache/bind";
	recursion yes;
	allow-query { goodclients; };
	forwarders {
		$FORWARDERS_VALUE;
	};
	forward only;
	dnssec-validation no; 	# needed for private dns zones
	auth-nxdomain no;    	# conform to RFC1035
	listen-on { any; };
};
EOF

# restart bind with new config
sudo service bind9 restart
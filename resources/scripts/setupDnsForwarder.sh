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

# ensure bind cache folder exists
sudo mkdir -p /var/cache/bind

# update bind configuration
sudo tee /etc/bind/named.conf.template <<EOF

acl goodclients {
    %CLIENTS%
    localhost;
    localnets;
};
options {
	directory "/var/cache/bind";
	recursion yes;
	allow-query { goodclients; };
	forwarders {
		%FORWARDERS%
	};
	forward only;
	dnssec-validation no; 	# needed for private dns zones
	auth-nxdomain no;    	# conform to RFC1035
	listen-on { any; };
};

EOF

sudo sed \
	-e "s/%CLIENTS%/$(printf "%s; " "${FORWARDERS[@]}")/g" \
	-e "s/%FORWARDERS%/$(printf "%s; " "${CLIENTS[@]}")/g" \
	/etc/bind/named.conf.template > /etc/bind/named.conf.options

# check bind configruation
sudo named-checkconf /etc/bind/named.conf.options

# restart bind with new configuration
sudo service bind9 restart
#!/bin/bash

FORWARDS=()
CLIENTS=()

while getopts 'n:f:c:' OPT; do
    case "$OPT" in
		n)
			NETWORKID="${OPTARG}" ;;
		f)
			FORWARDS+=("${OPTARG}") ;;
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
		%FORWARDS%
	};
	forward only;
	dnssec-validation no; 	# needed for private dns zones
	auth-nxdomain no;    	# conform to RFC1035
	listen-on { any; };
};

EOF

sudo sed \
	-e "s/%CLIENTS%/$(printf "%s; " "${CLIENTS[@]}")/g" \
	-e "s/%FORWARDS%/$(printf "%s; " "${FORWARDS[@]}")/g" \
	/etc/bind/named.conf.template > /etc/bind/named.conf.options

# check bind configruation
sudo named-checkconf /etc/bind/named.conf.options

# restart bind with new configuration
sudo service bind9 restart

# patch DNS on network 
az network vnet update \
	--ids NETWORKID \
	--dns-servers 168.63.129.16 $(jq -r '[.network.interface[].ipv4.ipAddress[].privateIpAddress]|join(" ")' ./metadata.json)
	
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

function errorHandler {

	# fallback to default DNS
	az network vnet update \
		--ids $NETWORKID \
		--dns-servers null \
		--output none

	echo "Error in line $1" | tee /dev/stderr && exit 1
}

trap "errorHandler $LINENO" ERR

for PEERCLIENT in $(az network vnet peering list --vnet-name $(basename $NETWORKID) --query '[?(allowVirtualNetworkAccess)].remoteAddressSpace.addressPrefixes[]' -o tsv); do
	[ ! -z "$PEERCLIENT" ] && CLIENTS+=("$PEERCLIENT")
done

# install required packages
sudo apt-get install -y bind9

# ensure bind cache folder exists
sudo mkdir -p /var/cache/bind

CLIENTS_VALUE="$(if [ ${#CLIENTS[@]} -eq 0 ]; then echo ''; else printf "%s; " "${CLIENTS[@]}"; fi)"
FORWARDS_VALUE="$(if [ ${#FORWARDS[@]} -eq 0 ]; then echo ''; else printf "%s; " "${FORWARDS[@]}"; fi)"

# update bind configuration
echo "Updating BIND9 configuration ..." && sudo tee /etc/bind/named.conf.options <<EOF

acl goodclients {
    $CLIENTS_VALUE
    localhost;
    localnets;
};

options {
	directory "/var/cache/bind";
	recursion yes;
	allow-query { goodclients; };
	forwarders {
		$FORWARDS_VALUE
		168.63.129.16;
	};
	forward only;
	dnssec-validation no; 	# needed for private dns zones
	auth-nxdomain no;    	# conform to RFC1035
	listen-on { any; };
};

EOF

# check bind configruation
sudo named-checkconf /etc/bind/named.conf.options

# restart bind with new configuration
sudo service bind9 restart

# patch DNS on network 
az network vnet update \
	--ids $NETWORKID \
	--dns-servers 168.63.129.16 $(jq -r '[.network.interface[].ipv4.ipAddress[].privateIpAddress]|join(" ")' ./metadata.json) \
	--output none

#!/bin/bash

ENDPOINT=''
IPRANGE='192.168.0.0/24'
ALLOWEDIPS=()
ISLANDIPS=()

while getopts 'e:r:a:i:' OPT; do
    case "$OPT" in
		e)
			ENDPOINT="${OPTARG}" ;;
		r)
			IPRANGE="${OPTARG}" ;;
		a)
			ALLOWEDIPS+=("${OPTARG}") ;;
		i)
			ISLANDIPS+=("${OPTARG}") ;;
    esac
done

# IPRANGE must be part of ALLOWEDIPS
ALLOWEDIPS+=("$IPRANGE")

# install required packages
sudo apt-get install -y coreutils iptables wireguard nmap 

# enable IP forwarding
sudo sed -i -e 's/#net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sudo sed -i -e 's/#net.ipv6.conf.all.forwarding.*/net.ipv6.conf.all.forwarding=1/g' /etc/sysctl.conf
sudo sysctl -p

# wipe any wireguard config
sudo rm -rf /etc/wireguard/*

# get all available IP addresses in the provided IP range / CIDR block
# CAUTION: leave the outer parenthesis where they are to get the result as array
IPADDRESSES=($(nmap -sL -n $IPRANGE | awk '/Nmap scan report/{print $NF}'))

SERVER_PORT=51820
SERVER_ENDPOINT="$ENDPOINT:$SERVER_PORT"
SERVER_PRIVATEKEY=$(wg genkey | sudo tee /etc/wireguard/server-privatekey)
SERVER_PUBLICKEY=$(echo $SERVER_PRIVATEKEY | wg pubkey | sudo tee /etc/wireguard/server-publickey)

echo "Creating WireGuard server configuration ..." && sudo tee /etc/wireguard/wg0.conf <<EOF

[Interface]
Address = ${IPADDRESSES[0]}
PrivateKey = $SERVER_PRIVATEKEY
ListenPort = $SERVER_PORT

EOF

ISLANDCOUNT=$((${#ISLANDIPS[@]}))

for (( i=1; i<=$ISLANDCOUNT; i++)); do
	echo "PostUp = iptables -A FORWARD -i %i -d ${ISLANDIPS[i]} -j ACCEPT" | sudo tee -a /etc/wireguard/wg0.conf
done

sudo tee -a /etc/wireguard/wg0.conf <<EOF

PostUp = iptables -A FORWARD -i %i -j DROP
PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

EOF

for (( i=1; i<=$ISLANDCOUNT; i++)); do
	echo "PostDown = iptables -D FORWARD -i %i -d ${ISLANDIPS[i]} -j ACCEPT" | sudo tee -a /etc/wireguard/wg0.conf
done

sudo tee -a /etc/wireguard/wg0.conf <<EOF

PostDown = iptables -D FORWARD -i %i -j DROP
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

EOF

for (( i=1 ; i<=$ISLANDCOUNT ; i++ )); do

	PEER_INDEX=$(printf "%03d" $i)
	PEER_PRIVATEKEY=$(wg genkey | sudo tee /etc/wireguard/peer$PEER_INDEX-privatekey)
	PEER_PUBLICKEY=$(echo $PEER_PRIVATEKEY | wg pubkey | sudo tee /etc/wireguard/peer$PEER_INDEX-publickey)
	PEER_ALLOWEDIPS=$(printf '%s, ' "${ALLOWEDIPS[@]}" | sed 's/[ ,]*$//g')

echo "Append WireGuard server configuration (PEER #$PEER_INDEX) ..." && sudo tee -a /etc/wireguard/wg0.conf <<EOF

[Peer]
PublicKey = $PEER_PUBLICKEY
AllowedIPs = ${IPADDRESSES[i]}/32

EOF

echo "Creating WireGuard peer configuration (PEER #$PEER_INDEX) ..." && sudo tee /etc/wireguard/wg0-peer$PEER_INDEX.conf <<EOF

[Interface]
Address = ${IPADDRESSES[i]}/32
PrivateKey = $PEER_PRIVATEKEY

[Peer]
PublicKey = $SERVER_PUBLICKEY
Endpoint = $SERVER_ENDPOINT
AllowedIPs = $PEER_ALLOWEDIPS
PersistentKeepalive = 20

EOF

done

# enable and start WireGuard service
# sudo systemctl enable wg-quick@wg0.service
# sudo systemctl start wg-quick@wg0.service
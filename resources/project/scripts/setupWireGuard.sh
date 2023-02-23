#!/bin/bash

ENDPOINT=''

while getopts 'e:a:' OPT; do
    case "$OPT" in
		e)
			ENDPOINT="${OPTARG}" ;;
    esac
done

# install required packages
sudo apt-get install -y wireguard coreutils

# enable IP forwarding
sudo sed -i -e 's/#net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sudo sed -i -e 's/#net.ipv6.conf.all.forwarding.*/net.ipv6.conf.all.forwarding=1/g' /etc/sysctl.conf
sudo sysctl -p

# wipe any wireguard config
sudo rm -rf /etc/wireguard/*

SERVER_PRIVATEIP=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}')
SERVER_PORT=51820
SERVER_ENDPOINT="$ENDPOINT:$SERVER_PORT"
SERVER_PRIVATEKEY=$(wg genkey | sudo tee /etc/wireguard/server-privatekey)
SERVER_PUBLICKEY=$(echo $PRIVATEKEY | wg pubkey | sudo tee /etc/wireguard/server-publickey)

echo "Creating WireGuard server configuration ..." && sudo tee /etc/wireguard/wg0.conf <<EOF

[Interface]
PrivateKey = $SERVER_PRIVATEKEY
Address = $SERVER_PRIVATEIP
ListenPort = $SERVER_PORT

EOF

for PEER_INDEX in {01..10}; do

	PEER_PRIVATEKEY=$(wg genkey | sudo tee /etc/wireguard/peer$PEER_INDEX-privatekey)
	PEER_PUBLICKEY=$(echo $PEER_PRIVATEKEY | wg pubkey | sudo tee /etc/wireguard/peer$PEER_INDEX-publickey)

echo "Append WireGuard server configuration (PEER #$PEER_INDEX) ..." && sudo tee -a /etc/wireguard/wg0.conf <<EOF

[Peer]
PublicKey = $PEER_PUBLICKEY
AllowedIPs = 0.0.0.0/0

EOF

echo "Creating WireGuard peer configuration (PEER #$PEER_INDEX) ..." && sudo tee /etc/wireguard/wg0-peer$PEER_INDEX.conf <<EOF

[Interface]
PrivateKey = $PEER_PRIVATEKEY

[Peer]
PublicKey = $SERVER_PUBLICKEY
Endpoint = $SERVER_ENDPOINT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 30

EOF

done

# enable and start WireGuard service
sudo systemctl enable wg-quick@wg0.service
sudo systemctl start wg-quick@wg0.service
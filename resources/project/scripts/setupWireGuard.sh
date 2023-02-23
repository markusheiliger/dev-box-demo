#!/bin/bash

ENDPOINT=''
ALLOWED=()

while getopts 'e:a:' OPT; do
    case "$OPT" in
		e)
			ENDPOINT="${OPTARG}" ;;
		a)
			ALLOWED+=("${OPTARG}") ;;
    esac
done

# install required packages
sudo apt-get install -y wireguard coreutils

# enable IP forwarding
sudo sed -i -e 's/#net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sudo sed -i -e 's/#net.ipv6.conf.all.forwarding.*/net.ipv6.conf.all.forwarding=1/g' /etc/sysctl.conf
sudo sysctl -p

SERVER_PRIVATEIP=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}')
SERVER_PORT=51820
SERVER_ENDPOINT="$ENDPOINT:$SERVER_PORT"
SERVER_PRIVATEKEY=$(wg genkey | sudo tee /etc/wireguard/server-privatekey)
SERVER_PUBLICKEY=$(echo $PRIVATEKEY | wg pubkey | sudo tee /etc/wireguard/server-publickey)

createPeer() {

	local PEER_PATH="/etc/wireguard/peer$1" 

	sudo mkdir -p $PEER_PATH

	local PEER_PRIVATEKEY=$(wg genkey | sudo tee $PEER_PATH/privatekey)
	local PEER_PUBLICKEY=$(echo $PRIVATEKEY | wg pubkey | sudo tee $PEER_PATH/publickey)
	local PEER_ALLOWED="$(if [ ${#ALLOWED[@]} -eq 0 ]; then echo ''; else printf "%s, " "${ALLOWED[@]}"; fi)"

echo "Creating WireGuard peer configuration ..." && sudo tee $PEER_PATH/wg0.conf <<EOF

[Interface]
PrivateKey = $PEER_PRIVATEKEY

[Peer]
PublicKey = $SERVER_PUBLICKEY
Endpoint = $SERVER_ENDPOINT
AllowedIPs = $PEER_ALLOWED

EOF

echo "Append WireGuard server configuration ..." && sudo tee -a /etc/wireguard/wg0.conf <<EOF

[Peer]
PublicKey = $PEER_PUBLICKEY
AllowedIPs = $PEER_ALLOWED

EOF

}

echo "Creating WireGuard server configuration ..." && sudo tee /etc/wireguard/wg0.conf <<EOF

[Interface]
PrivateKey = $SERVER_PRIVATEKEY
Address = $SERVER_PRIVATEIP
ListenPort = $SERVER_PORT

EOF

# enable WireGuard service
sudo systemctl enable wg-quick@wg0.service
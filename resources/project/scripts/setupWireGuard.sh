#!/bin/bash

ENDPOINT=''
HRANGE=''
VRANGE=''
IRANGES=()

while getopts 'e:h:r:i:' OPT; do
    case "$OPT" in
		e)
			ENDPOINT="${OPTARG}" ;;
		h)
			HRANGE="${OPTARG}" ;;
		v)
			VRANGE="${OPTARG}" ;;
		i)
			IRANGES+=("${OPTARG}") ;;
    esac
done

# install required packages
sudo apt-get install -y coreutils iptables wireguard nmap 

# enable IP forwarding
sudo sed -i -e 's/#net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sudo sed -i -e 's/#net.ipv6.conf.all.forwarding.*/net.ipv6.conf.all.forwarding=1/g' /etc/sysctl.conf
sudo sysctl -p

# get all available IP addresses in the provided IP range / CIDR block
# CAUTION: leave the outer parenthesis where they are to get the result as array
VRANGEIPS=($(nmap -sL -n $VRANGE | awk '/Nmap scan report/{print $NF}'))

SERVER_PATH='/etc/wireguard'
sudo rm -rf $SERVER_PATH/*

SERVER_PORT=51820
SERVER_ENDPOINT="$ENDPOINT:$SERVER_PORT"
SERVER_PRIVATEKEY=$(wg genkey | sudo tee $SERVER_PATH/privateKey)
SERVER_PUBLICKEY=$(echo $SERVER_PRIVATEKEY | wg pubkey | sudo tee $SERVER_PATH/publicKey)

echo "Creating WireGuard server configuration ..." && sudo tee $SERVER_PATH/wg0.conf <<EOF

[Interface]
Address = ${VRANGEIPS[0]}
PrivateKey = $SERVER_PRIVATEKEY
ListenPort = $SERVER_PORT

PostUp = iptables -I FORWARD 1 -i %i -j ACCEPT
PostUp = iptables -t nat -I POSTROUTING 1 -o eth0 -j MASQUERADE

PostDown = iptables -D FORWARD -i %i -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

EOF

IRANGESCOUNT=$((${#IRANGES[@]}))

for (( i=0 ; i<$IRANGESCOUNT ; i++ )); do

	PEER_PATH="$SERVER_PATH/island-$PEER_INDEX"
	sudo mkdir $PEER_PATH
	
	PEER_INDEX=$(printf "%03d" $(($i + 1)))
	PEER_PRIVATEKEY=$(wg genkey | sudo tee $PEER_PATH/privateKey)
	PEER_PUBLICKEY=$(echo $PEER_PRIVATEKEY | wg pubkey | sudo tee $PEER_PATH/publicKey)

echo "Append WireGuard server configuration (ISLAND #$PEER_INDEX) ..." && sudo tee -a $SERVER_PATH/wg0.conf <<EOF

[Peer]
PublicKey = $PEER_PUBLICKEY
AllowedIPs = $VRANGE, ${IRANGES[i]}
PersistentKeepalive = 20

EOF

echo "Creating WireGuard peer configuration (ISLAND #$PEER_INDEX) ..." && sudo tee $PEER_PATH/wg0.conf <<EOF

[Interface]
Address = ${VRANGEIPS[(i+1)]}/32
PrivateKey = $PEER_PRIVATEKEY

PostUp = iptables -I FORWARD 1 -i %i -j ACCEPT
PostUp = iptables -t nat -I POSTROUTING 1 -o eth0 -j MASQUERADE

PostDown = iptables -D FORWARD -i %i -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $SERVER_PUBLICKEY
Endpoint = $SERVER_ENDPOINT
AllowedIPs = $VRANGE, $HRANGE
PersistentKeepalive = 20

EOF

done

# enable and start WireGuard service
# sudo systemctl enable wg-quick@wg0.service
# sudo systemctl daemon-reload
# sudo systemctl start wg-quick@wg0.service
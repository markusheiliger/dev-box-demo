#!/bin/bash

# update and upgrade packages
sudo apt-get update && sudo apt-get upgrade -y

# install required packages
sudo apt-get install coreutils curl jq wireguard -y

# enable IP forwarding
sudo sed -i -e 's/#net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sudo sed -i -e 's/#net.ipv6.conf.all.forwarding.*/net.ipv6.conf.all.forwarding=1/g' /etc/sysctl.conf
sudo sysctl -p

# open and enable firewall
# sudo ufw allow 51820/udp
# sudo ufw enable

WIREGUARD_IPPATTERN='10.0.0.*/24'

# create server keys
SERVER_PRIVATEKEY=$(wg genkey | sudo tee /etc/wireguard/private.key)
SERVER_PUBLICKEY=$(echo $SERVER_PRIVATEKEY | wg pubkey | sudo tee /etc/wireguard/public.key)
SERVER_IPADDRESS=$(echo $WIREGUARD_IPPATTERN | sed -r 's/\*/1/g')
SERVER_DEVICE$(ip -o -4 route show to default | awk '{print $5}')
SERVER_PRIVATEIP=$(curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance/network/interface?api-version=2021-02-01" | jq --raw-output '.[0].ipv4.ipAddress[0].privateIpAddress')
SERVER_PUBLICIP=$(curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance/network/interface?api-version=2021-02-01" | jq --raw-output '.[0].ipv4.ipAddress[0].publicIpAddress')

registerClient() {

local CLIENT_NAME=$1

sudo mkdir /etc/wireguard/$CLIENT_NAME

local CLIENT_COUNT=$(find /etc/wireguard -mindepth 1 -maxdepth 1 -type d 2> /dev/null | wc -l)
local CLIENT_PRIVATEKEY=$(wg genkey | sudo tee /etc/wireguard/${CLIENT_NAME}/private.key)
local CLIENT_PUBLICKEY=$(echo $CLIENT_PRIVATEKEY | wg pubkey | sudo tee /etc/wireguard/${CLIENT_NAME}/public.key)
local CLIENT_IPADDRESS=$(echo $WIREGUARD_IPPATTERN | sed -r "s/\*/$((CLIENT_COUNT+2))/g")

echo "Creating config for client $CLIENT_NAME ..." && sudo tee /etc/wireguard/$CLIENT_NAME/wg0.conf <<EOF

[Interface]
PrivateKey = ${CLIENT_PRIVATEKEY}
Address = ${CLIENT_IPADDRESS}

[Peer] 
PublicKey = ${SERVER_PUBLICKEY}
Endpoint = ${SERVER_HOST}:51820
AllowedIPs = ${SERVER_IPADDRESS}/24
PersistentKeepalive = 15

EOF

echo "Appending config for client $CLIENT_NAME in server config ..." && sudo tee -a /etc/wireguard/wg0.conf <<EOF

[Peer] ## ${CLIENT_NAME}
PublicKey = ${CLIENT_PUBLICKEY}
AllowedIPs = ${CLIENT_IPADDRESS}

EOF

}

echo "Creating config for server ..." && sudo tee /etc/wireguard/wg0.conf <<EOF

[Interface]
PrivateKey = ${SERVER_PRIVATEKEY}
Address = ${SERVER_IPADDRESS}/24
ListenPort = 51820

EOF

registerClient 'TEST'

# sudo systemctl enable wg-quick@wg0
# sudo systemctl start wg-quick@wg0

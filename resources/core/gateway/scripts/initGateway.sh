#!/bin/bash

# ==========================================================================================================================================
# SETUP
# ==========================================================================================================================================

# update and upgrade packages
sudo apt-get update && sudo apt-get install -y --no-install-recommends apt-utils && sudo apt-get upgrade -y

# auto confirm iptables-persistent prompts
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections

# install required packages
sudo apt-get install -y --no-install-recommends iptables iptables-persistent

# enable IP forwarding
sudo sed -i -e 's/#net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sudo sed -i -e 's/#net.ipv6.conf.all.forwarding.*/net.ipv6.conf.all.forwarding=1/g' /etc/sysctl.conf
sudo sysctl -p

# block forwarding for new packages from the organization IP range
sudo iptables -A FORWARD -i eth0 -s 192.168.1.0/24 -m state --state NEW -j DROP

# accept forwarding for established and related packages
sudo iptables -A FORWARD -i eth0 -o eth0 -m state --state ESTABLISHED,RELATED -j ACCEPT

# enable forwarding for environment IP range and maquerade
sudo iptables -A FORWARD -i eth0 -o eth0 -s 192.168.3.0/24 -j ACCEPT
sudo iptables -t nat -A POSTROUTING -s 192.168.3.0/24 -o eth0 -j MASQUERADE

sudo iptables-save > /etc/iptables/rules.v4

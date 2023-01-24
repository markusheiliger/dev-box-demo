#!/bin/bash

export DEBCONF_NOWARNINGS=yes
export DEBIAN_FRONTEND=noninteractive

# patch needrestart config
[ -f '/etc/needrestart/needrestart.conf' ] \
	&& sed -i 's/#$nrconf{restart}.*/$nrconf{restart} = '"'"'l'"'"';/g' /etc/needrestart/needrestart.conf

# update and upgrade packages
sudo apt-get update -y && sudo apt-get upgrade -y 

# install commonly used packages
sudo apt-get install -y apt-utils apt-transport-https coreutils jq

# install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# configure Azure CLI
az config set \
	defaults.location=westus2 \
	defaults.group=MyResourceGroup

# login and set subscription context
az login --identity --allow-no-subscriptions
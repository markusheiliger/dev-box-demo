#!/bin/bash

# patch needrestart config
[ -f '/etc/needrestart/needrestart.conf' ] \
	&& sed -i 's/#$nrconf{restart}.*/$nrconf{restart} = '"'"'l'"'"';/g' /etc/needrestart/needrestart.conf

# update and upgrade packages
sudo apt-get update && sudo apt-get upgrade -y 

# install commonly used packages
sudo apt-get install -y apt-utils coreutils

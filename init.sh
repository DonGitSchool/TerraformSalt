#!/bin/bash

echo "${ maddress } salt" >> /etc/hosts
wget -O /tmp/install.sh https://bootstrap.saltstack.com
chmod +x /tmp/install.sh
source /tmp/install.sh

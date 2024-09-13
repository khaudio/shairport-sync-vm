#!/bin/bash

# Run to pull repo and start setup.
# Do not run if you already have repo on the VM;
# instead, start with setup01.sh.

apt update
apt -y install git
cd ~
git clone https://github.com/khaudio/shairport-sync-vm.git
cd shairport-sync-vm
chmod +x ./*.sh
setup01.sh

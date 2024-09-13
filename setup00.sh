#!/bin/bash

# Run to pull repo and start setup.
# Do not run if you already have repo on the VM;
# instead, start with setup01.sh.

set -e
cd ~
apt update
apt -y install git
git clone https://github.com/khaudio/shairport-sync-vm.git
cd shairport-sync-vm
chmod +x ./*.sh

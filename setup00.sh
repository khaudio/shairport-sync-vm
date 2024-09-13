#!/bin/bash

# Run to pull repo.  To start setup, run setup01.sh

cd ~; apt update; apt -y install git && git clone https://github.com/khaudio/shairport-sync-vm.git && cd shairport-sync-vm; chmod +x ./*.sh

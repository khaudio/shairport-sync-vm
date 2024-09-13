#!/bin/bash

# Run after initial VM creation

hostnamectl set-hostname airplay-001
passwd

cp ./template/shairport-sync.conf ~/shairport-sync.conf
mkdir ~/bin

cat > ~/bin/cp-sps-conf.sh << EOF
cp ~/shairport-sync.conf /etc/shairport-sync.conf
systemctl restart shairport-sync
EOF

cat > ~/bin/reset-machine-id.sh << EOF
echo "Resetting Machine ID..."
echo -n >/etc/machine-id
rm /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id
echo "Machine ID reset"
EOF

cat > ~/bin/set-hostname.sh << EOF
read -p "Enter hostname: " HOSTNAME
hostnamectl set-hostname $HOSTNAME
EOF

cat > ~/bin/enable-root-ssh.sh << EOF
echo PermitRootLogin yes >> /etc/ssh/sshd_config
systemctl enable sshd
systemctl restart sshd
EOF

cat > ~/bin/disable-root-ssh.sh << EOF
sed -i -e '/PermitRootLogin yes/d' /etc/ssh/sshd_config
systemctl disable sshd
systemctl restart sshd
EOF

cat > ~/prepare_template_before_cloning.sh << EOF
~/bin/reset-machine-id.sh
EOF

cat > ~/run_on_cloned_machine.sh << EOF
~/bin/set-hostname.sh
~/bin/cp-sps-conf.sh
~/bin/disable-root-ssh.sh
reboot
EOF

chmod +x ~/*.sh
chmod +x ~/bin/*.sh

apt update
apt -y install openssh-server gdisk parted \
fdisk usbutils alsa-utils

parted < expanddisk.txt
reboot

#!/bin/bash

# Run after initial VM creation

set -e

read -p "Enter hostname: " HOSTNAME
hostnamectl set-hostname $HOSTNAME

# Uncomment to set root password.  This is removed because
# although we are installing openssh, we are not enabling
# sshd by default.

# passwd

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
systemctl start sshd
EOF

cat > ~/bin/disable-root-ssh.sh << EOF
sed -i -e '/PermitRootLogin yes/d' /etc/ssh/sshd_config
systemctl stop sshd
systemctl disable sshd
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
apt -y install parted openssh-server

printf "fix\n1\nyes\n-0" | parted ---pretend-input-tty /dev/sda resizepart

cat > /etc/systemd/system/sps-install.service << EOF
[Unit]
Description=Run script at next reboot
Before=reboot.target
DefaultDependencies=no

[Service]
Type=oneshot
ExecStart=/root/shairport-sync-vm/setup02.sh
EOF

systemctl daemon-reload
systemctl enable sps-install

reboot

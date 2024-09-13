# shairport-sync-vm
Auto setup for shairport-sync in a virtual machine in Proxmox VE

Upload debian nocloud raw image to proxmox user home dir.  You can find the image at `https://www.debian.org/distrib/` and download the raw image under `a local QEMU virtual machine, in qcow2 or raw formats`.  Alternatively, download it directly from `https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-nocloud-amd64.raw`.

## On Host:

Create a vm in proxmox.  In this example, the vmid is `101`, scsi controller is `VirtIO SCSI single`, and on `scsi0` we create an `4 GB` `zfs` dataset.  We'll give it `2` Cores and `2048 MB` of memory (`512` minimum since we are enabling `Qemu Agent` under `System`).  Set network bridge to  `vmbr0` and uncheck `Firewall`.  You can give it more CPU/memory so the install will go faster; just remember to take it back, later.  Even with `soxr` enabled, it uses very little CPU in operation.

Select the newly created vm in the proxmox web interface, go to `Hardware`, remove the `CD-ROM` drive, as it is not needed, and note the name of `Hard Disk (scsi0)`.

Plug in the USB DAC, add it to the new VM using `Add` --> `USB Device`.  Pick an option and select the DAC.  If there are no other usb devices passed through, it should be added to the `Hardware` menu as `usb0`.

Go to `Options`, then edit `Boot Order` and ensure that `scsi0` is either boot option number 1 or the only option selected.

Where `101` is the vmid, `vm-101-disk-1` is an empty `zfs` dataset for the vm, `scsi0` is the storage controller, the image `debian-12-nocloud-amd64.raw` resides in `/root`, and the user is logged in as `root`.

```bash
cd ~
dd if=debian-12-nocloud-amd64.raw of=/dev/zvol/rpool/data/vm-101-disk-1 bs=1M status=progress
```

If your zfs dataset isn't big enough to hold the image + updates, add capacity to it with (where `+2G` add 2 GB to the dataset):

```bash
qm resize 101 scsi0 +2G
```

Boot the vm and login as `root` (no default pw).

## On Guest

Run `setup01.sh`, reboot, then run `setup02.sh`.  Alternativley, follow the steps, below.

Where `airplay-001` is the desired hostname for the virtual machine

`hostnamectl set-hostname airplay-001`
`passwd`

follow the prompts to enter a password.

```bash
apt update
apt -y upgrade
apt -y install openssh-server
&& echo PermitRootLogin yes >> /etc/ssh/sshd_config
```

Alternatively, open the ssh config file and manually change the flag

```bash
vim /etc/ssh/sshd_config
```

change `PermitRootLogin` to `yes`

```bash
systemctl restart sshd
systemctl status sshd
```
Example output of `ip addr show` shows `192.168.1.99`

## On Remote Machine

Login to the new vm via `ssh`.

ssh `root@192.168.1.99`

### Resize partition to fill volume

```bash
apt -y install parted usbutils alsa-utils
```

```bash
parted /dev/sda
```

in parted:

```
print
```

If prompted to fill volume by typing `Fix`... do it.

```
fix
resizepart 1
yes
-0
quit
```

`reboot`, then ssh into the vm again and verify the disk has expanded with `df -h`

```bash
root@debian-audio-003:~# df -h
Filesystem      Size  Used Avail Use% Mounted on
udev            948M     0  948M   0% /dev
tmpfs           194M  784K  193M   1% /run
/dev/sda1       3.8G  1.2G  2.5G  33% /
tmpfs           966M     0  966M   0% /dev/shm
tmpfs           5.0M   12K  5.0M   1% /run/lock
/dev/sda15      124M   12M  113M  10% /boot/efi
tmpfs           194M     0  194M   0% /run/user/0
```

`/dev/sda1       3.8G` shows us that it can now use the entire 4 GB dataset we allocated.  You may want to allocate more or less.

Check audio devices with `aplay -l` and/or `aplay -L`.
If there are no devices listed, plug in and add (via the host `Hardware` menu) the audio USB DAC now.  This is only if you forgot to do it earlier.

Using the below includes a number of optional features in compilation; however, many are disabled by default or require further configuration, if you want to use them.  Things like mqtt are included in case you want to publish metadata and album art to a display or other machine on your network.

```bash
apt install --no-install-recommends -y build-essential git autoconf automake \
libtool libpopt-dev libconfig-dev libasound2-dev avahi-daemon \
libavahi-client-dev libglib2.0-dev libmosquitto-dev libssl-dev libsoxr-dev \
libplist-dev libsndfile1-dev libsodium-dev libavutil-dev libavcodec-dev \
libavformat-dev uuid-dev libgcrypt-dev xxd usbutils alsa-utils \
qemu-guest-agent htop
```

Install `nqptp` first

```bash
cd
git clone https://github.com/mikebrady/nqptp.git
cd nqptp
autoreconf -fi
./configure --with-systemd-startup
make
make install
systemctl enable nqptp
systemctl start nqptp
```

Then, optionally, Apple ALAC

```bash
cd
git clone https://github.com/mikebrady/alac.git
cd alac
autoreconf -fi
./configure
make
make install && ldconfig
```

And finally, `shairport-sync`, itself

```bash
cd
git clone https://github.com/mikebrady/shairport-sync.git
cd shairport-sync
autoreconf -fi
./configure --sysconfdir=/etc --with-airplay-2 --with-alsa --with-pipe \
--with-soxr --with-apple-alac --with-convolution --with-metadata \
--with-mqtt-client --with-dbus-interface --with-systemd --with-ssl=openssl \
--with-avahi --with-os=linux --with-configfiles \
&& make && make install
```

## Configuration, Testing, and Troubleshooting

Test it with `shairport-sync -v --statistics`

If everything works, cancel it with `Ctrl+C`, then enable and start the service with

```bash
systemctl enable shairport-sync
systemctl start shairport-sync
```

If it doesn't work, check your alsa devices with `aplay -L` and configure the conf file `/etc/shairport-sync.conf`.  You can copy/paste the name of the default alsa device (e.g. `default:CARD=Device`) into `output_device` under the `alsa` section.  Go ahead and configure the rest of your desired settings like `name` in this file.  I raise `default_airplay_volume` to `-16.0`.

Monitor the systemd service with `journalctl -f -u shairport-sync.service` and/or run `htop` while connecting via Airplay with a remote device.  If you get crackling audio, you may have selected the wrong alsa device.

Optionally reboot and test again.  If you need multiple receivers (or for a more permanent setup), consider labeling each device/port, and passing through entire USB ports, rather than by vendor/device ID.

Running `df -h` again shows `1.4G` free, which should be plenty for metadata caching.  You can remove the source folders in `~` if you want more space, or extend the volume on the host using the `qm resize` command.

If you bumped up the VM's resources, remember to scale them back when you're finished configuring, and also remove or comment the `PermitRootLogin yes` line from `/etc/ssh/sshd_config` to disable root `ssh` login.


## Convenience Scripts to Leave on a Template VM

I copied the conf file to $HOME to backup my changes and modify there instead of `/etc`, but this is not needed.

```bash
cd
cp /etc/shairport-sync.conf .
```

Make a subdir to keep things tidy

```bash
cd
mkdir bin
```

Copy the modified conf file back to `/etc` if needed and reload the service

```bash
cat > cp-sps-conf.sh << EOF
cp ~/shairport-sync.conf /etc/shairport-sync.conf
systemctl restart shairport-sync
EOF
```

Change the machine ID before cloning the VM to avoid duplicate ipv6 addresses

```bash
cat > ~/bin/reset-machine-id.sh << EOF
echo "Resetting Machine ID..."
echo -n >/etc/machine-id
rm /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id
echo "Machine ID reset"
EOF
```

Change the hostname after cloning

```bash
cat > ~/bin/set-hostname.sh << EOF
read -p "Enter hostname: " HOSTNAME
hostnamectl set-hostname $HOSTNAME
EOF
```

```bash
cat > ~/bin/disable-root-ssh.sh << EOF
sed -i -e '/PermitRootLogin yes/d' /etc/ssh/sshd_config
systemctl stop sshd
systemctl disable sshd
EOF
```

```bash
cat > ~/bin/enable-root-ssh.sh << EOF
echo PermitRootLogin yes >> /etc/ssh/sshd_config
systemctl enable sshd
systemctl restart sshd
EOF
```

Convenience scripts in `$HOME`

```bash
cat > ~/prepare_template_before_cloning.sh << EOF
~/bin/reset-machine-id.sh
EOF
```

```bash
cat > ~/run_on_cloned_machine.sh << EOF
~/bin/set-hostname.sh
~/bin/cp-sps-conf.sh
~/bin/disable-root-ssh.sh
reboot
EOF
```

Make them all executable

```bash
chmod +x ~/*.sh
chmod +x ~/bin/*.sh
```

To clone

- Run `prepare_template_before_cloning.sh` on the template
- Power off the VM
- Clone the VM
- Plug in and add a new output in `Hardware`
- Boot the VM and run `run_on_cloned_machine.sh`
- Test the cloned VM

`shairport-sync.conf` template is included. As noted, you may want to change `name`, and will likely need to change `output_device` to match what you have displayed in `aplay -L`.


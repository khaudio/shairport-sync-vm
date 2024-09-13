#!/bin/bash

# Run after reboot after running setup01.sh

set -e

apt update && apt -y upgrade
apt install --no-install-recommends -y build-essential git autoconf automake \
libtool libpopt-dev libconfig-dev libasound2-dev avahi-daemon \
libavahi-client-dev libglib2.0-dev libmosquitto-dev libssl-dev libsoxr-dev \
libplist-dev libsndfile1-dev libsodium-dev libavutil-dev libavcodec-dev \
libavformat-dev uuid-dev libgcrypt-dev xxd usbutils alsa-utils \
qemu-guest-agent htop

cd
git clone https://github.com/mikebrady/nqptp.git
cd nqptp
autoreconf -fi
./configure --with-systemd-startup
make
make install
systemctl enable nqptp
systemctl start nqptp

cd
git clone https://github.com/mikebrady/alac.git
cd alac
autoreconf -fi
./configure
make
make install && ldconfig

cd
git clone https://github.com/mikebrady/shairport-sync.git
cd shairport-sync
autoreconf -fi
./configure --sysconfdir=/etc --with-airplay-2 --with-alsa --with-pipe \
--with-soxr --with-apple-alac --with-convolution --with-metadata \
--with-mqtt-client --with-dbus-interface --with-systemd --with-ssl=openssl \
--with-avahi --with-os=linux --with-configfiles \
&& make && make install

ALSADEVICE=$(aplay -L | grep default: | grep -v sysdefault:)
sed -i "s/default:CARD=Device/$ALSADEVICE/g" ~/shairport-sync.conf

~/bin/cp-sps-conf.sh
systemctl stop shairport-sync
systemctl enable shairport-sync
systemctl start shairport-sync


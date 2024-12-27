#!/bin/bash
#
# https://github.com/gitbls/sdm/blob/master/Docs/Command-Details.md
# https://github.com/gitbls/sdm/blob/master/Docs/Plugins.md
# TODO https://github.com/gitbls/sdm/blob/master/Docs/Plugins.md#gadgetmode
# serial is not working right
#

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <rpi image realtive path>"
    exit 1
fi

sudo sdm --customize \
--plugin user:"deluser=pi" \
--plugin user:"adduser=tcronin" \
--plugin user:"setpassword=tcronin|password=$TEC_PWD" \
--plugin sshkey:"sshuser=tcronin|keyname=authorized_keys|import-key=/mnt/clones/data/home/tcronin/.ssh/authorized_keys" \
--plugin copyfile:"from=src/home/.bash_aliases|to=/home/tcronin|runphase=postinstall|chown=tcronin:tcronin|chmod=644" \
--plugin user:"adduser=ansible" \
--plugin user:"setpassword=ansible|password=$ANS_PWD" \
--plugin sshkey:"sshuser=ansible|keyname=authorized_keys|import-key=/mnt/clones/data/home/ansible/.ssh/authorized_keys" \
--plugin copyfile:"from=src/etc/profile.d/motd.sh|to=/etc/profile.d|runphase=postinstall|chown=root:root|chmod=644" \
--plugin L10n:"keymap=us|locale=en_US.UTF-8|timezone=America/Chicago" \
--plugin disables:"bluetooth|triggerhappy|piwiz" \
--plugin network:"netman=nm|ifname=wlan0|wifissid=tec-wan|wifipassword=$WIFI_PWD|wificountry=US" \
--extend --xmb 4096 \
--regen-ssh-host-keys \
--reboot 5 \
--nowait-timesync \
--redact \
$1

# shrink image
sudo sdm --shrink $1
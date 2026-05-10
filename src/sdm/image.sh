#!/bin/bash
#
# https://github.com/gitbls/sdm/blob/master/Docs/Command-Details.md
# https://github.com/gitbls/sdm/blob/master/Docs/Plugins.md
# TODO https://github.com/gitbls/sdm/blob/master/Docs/Plugins.md#gadgetmode
# serial is not working right
#

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <rpi image realtive path> <user-data.yml relative path>"
    exit 1
fi

# TODO pcie for pi 5``
#--plugin bootconfig:"dtparam=pciex1" \
#--plugin bootconfig:"dtparam=pciex1_gen=2" \

sudo sdm --customize \
--plugin cloudinit:"userdata=$2" \
--plugin network:"netman=nm|ifname=wlan0|wifissid=tec-wan|wifipassword=$WIFI_PWD|wificountry=US" \
--extend --xmb 4096 \
--regen-ssh-host-keys \
--reboot 5 \
--nowait-timesync \
--redact \
$1

# shrink image
sudo sdm --shrink $1
# https://github.com/gitbls/sdm/blob/master/Docs/Command-Details.md
# https://github.com/gitbls/sdm/blob/master/Docs/Plugins.md
# keep script for when needing to run interactive
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
--plugin mkdir:"dir=/home/tcronin/.ssh|chown=tcronin:tcronin|chmod=700" \
--plugin copyfile:"from=/mnt/clones/data/home/tcronin/.ssh/authorized_keys|to=/home/tcronin/.ssh|runphase=postinstall|chown=tcronin:tcronin|chmod=600" \
--plugin copyfile:"from=src/home/.bash_aliases|to=/home/tcronin|runphase=postinstall|chown=tcronin:tcronin|chmod=644" \
--plugin user:"adduser=ansible" \
--plugin user:"setpassword=ansible|password=$ANS_PWD" \
--plugin mkdir:"dir=/home/ansible/.ssh|chown=ansible:ansible|chmod=700" \
--plugin copyfile:"from=/mnt/clones/data/home/ansible/.ssh/authorized_keys|to=/home/ansible/.ssh|runphase=postinstall|chown=ansible:ansible|chmod=600" \
--plugin copyfile:"from=src/etc/profile.d/motd.sh|to=/etc/profile.d|runphase=postinstall|chown=root:root|chmod=644" \
--plugin L10n:"keymap=us|locale=en_US.UTF-8|timezone=America/Chicago" \
--plugin disables:"triggerhappy|piwiz" \
--plugin network:"netman=nm" \
--extend --xmb 4096 \
--regen-ssh-host-keys \
--reboot 5 \
--nowait-timesync \
--redact \
$1

# current issue with wifi pwd /w spaces
#--plugin network:"netman=nm|wifissid=tec-wan|wifipassword=$WIFI_PWD|wificountry=US" \

# shrink image
sudo sdm --shrink $1
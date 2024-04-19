# https://github.com/gitbls/sdm/blob/master/Docs/Command-Details.md
# https://github.com/gitbls/sdm/blob/master/Docs/Plugins.md
#
sudo sdm --customize \
--plugin user:"adduser=tcronin|password=$TEC_PWD" \
--plugin mkdir:"dir=/home/tcronin/.ssh|chown=tcronin:tcronin|chmod=700" \
--plugin copyfile:"from=/mnt/clones/data/home/tcronin/.ssh/authorized_keys|to=/home/tcronin/.ssh|runphase=postinstall|chown=tcronin:tcronin|chmod=600" \
--plugin user:"adduser=ansible|password=$ANS_PWD" \
--plugin mkdir:"dir=/home/ansible/.ssh|chown=ansible:ansible|chmod=700" \
--plugin copyfile:"from=/mnt/clones/data/home/ansible/.ssh/authorized_keys|to=/home/ansible/.ssh|runphase=postinstall|chown=ansible:ansible|chmod=600" \
--plugin user:"deluser=pi" \
--plugin L10n:"keymap=us|locale=en_US.UTF-8|timezone=America/Chicago" \
--plugin disables:piwiz \
--plugin network:"netman=nm|wifissid=tec-wan|wifipassword=$WIFI_PWD|wificountry=US" \
--redact \
--regen-ssh-host-keys \
--reboot 5 \
--nowait-timesync \
img/bookworm.img

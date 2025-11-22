alias cls='printf "\033c"'
alias osver="cat /etc/os-release | egrep -o  PRETTY_NAME=.* | sed -E 's/PRETTY_NAME=\"(.+)\"/\1/'"
alias piver='cat /proc/device-tree/model;printf "\n"'
alias pimem="free -mh | egrep -0 Mem:.* | sed -E 's/Mem:\s+([0-9]+\.?[0-9]?[GMi]{2})\s+.*/\1/'"
alias pidisk="df -h | egrep -0 /dev/root.* | sed -E 's/\/dev\/root\s+([0-9]+[GM]?)\s+([0-9\.]+[GM]?)\s+([0-9\.]+[GM]?).*/disk total:\1 used:\2/'"
alias pitemp='vcgencmd measure_temp | egrep -o "[0-9]*\.[0-9]*.{2}"'
alias ssdtemp="sudo smartctl -a /dev/nvme0n1 | egrep '^Temperature:' | sed -E 's/.*([0-9]{2})\s+(\w*)/\1 \2/'"
alias watchfreq="watch vcgencmd measure_clock arm"
alias listsvc='systemctl list-unit-files --type=service'
alias listenable='systemctl list-unit-files --type=service --state=enabled'
alias liteon='sudo bash -c "echo 0 > /sys/class/backlight/rpi_backlight/bl_power"'
alias liteoff='sudo bash -c "echo 1 > /sys/class/backlight/rpi_backlight/bl_power"'
alias hdmion='sudo vcgencmd display_power 0'
alias hdmioff='sudo vcgencmd display_power 1'
alias timesync='sudo ntpdate -s time.nist.gov'
alias timesrv='timedatectl show-timesync | grep ServerAddress'
alias jimmies='echo 1 | sudo tee /proc/sys/kernel/sysrq;echo s | sudo tee /proc/sysrq-trigger;echo u | sudo tee /proc/sysrq-trigger;echo b | sudo tee /proc/sysrq-trigger'
alias gitclean='git fetch; git reflog expire --expire=now --all; git gc --prune=now; git remote prune origin; git fsck --full'
alias svclst='sudo systemctl list-units --state running'
alias pwdany='head -c 512 /dev/urandom  | tr -dc [:graph:] |  head -c 12'
alias pwdalnu='head -c 512 /dev/urandom  | tr -dc [:alnum:] |  head -c 12'
alias tokengen='openssl rand -base64 48'
alias winkey='sudo strings /sys/firmware/acpi/tables/MSDM'
alias ntpsvr='timedatectl timesync-status'
alias netconf='resolvectl status'
alias netdev='sudo lshw -c network'
alias clpreset='sudo pkill -f VBoxClient && sudo VBoxClient --clipboard'
alias pvenv='source ./.venv/bin/activate'

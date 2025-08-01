#!/bin/sh
#
# motd script
# https://zsitko.com/welcome-message-motd-raspberry-pi/
# https://krishna-alagiri.medium.com/raspberry-pi-awesome-custom-motd-db16e0c1902
# https://forums.raspberrypi.com/viewtopic.php?t=23440
# https://upload.wikimedia.org/wikipedia/commons/1/15/Xterm_256color_chart.svg 
# https://linuxcommand.org/lc3_adv_tput.php
#
let upSeconds="$(/usr/bin/cut -d. -f1 /proc/uptime)"
let secs=$((${upSeconds}%60))
let mins=$((${upSeconds}/60%60))
let hours=$((${upSeconds}/3600%24))
let days=$((${upSeconds}/86400))

OSVER=`cat /etc/os-release | egrep -o  PRETTY_NAME=.* | sed -E 's/PRETTY_NAME=\"(.+)\"/\1/'`
PIVER=`cat /proc/cpuinfo | egrep Model.*:.* | sed -E 's/Model\s+:\s+(.*)/\1/'`
MEM=`free -gh --si | egrep -o Mem:.* | sed -E 's/\Mem:\s+([0-9\.]+[GMK]?)\s+([0-9\.]+[GMK]?)\s+([0-9\.]+[GMK]?)\s+([0-9\.]+[GMK]?)\s+([0-9\.]+[GMK]?)\s+([0-9\.]+[GMK]?)/total: \1 used: \2 free: \3/'`
DISK=`df -h / | egrep -o '/dev/.*' | sed -E 's/\/dev\/\w+\s+([0-9]+[GM]?)\s+([0-9\.]+[GM]?)\s+([0-9\.]+[GM]?).*/total: \1 used: \2 free: \3/'`
UPTIME=`printf "%d days, %02d:%02d:%02d" "$days" "$hours" "$mins" "$secs"`
PROC_CNT=`ps -e | wc -l`
KERNVER=`uname -rm`
INT_IP_ADDR=`hostname -I | /usr/bin/cut -d " " -f 1`
EXT_IP_ADDR=`wget -q -O - http://icanhazip.com/ | tail`
#UPGRADE_CNT=`sudo apt update &> /dev/null && apt list --upgradable 2>/dev/null | grep -c upgradable`
UPGRADE_CNT=`apt list --upgradable 2>/dev/null | grep -c upgradable`

# get the load averages
read one five fifteen rest < /proc/loadavg

#clear
echo "$(tput setaf 2)"
echo "    .~~.   .~~."
echo "   '. \ ' ' / .'$(tput setaf 1)"
echo "    .~ .~~~..~.    $(tput sgr0)$(tput bold)                 _                          _ $(tput sgr0)$(tput setaf 1)"
echo "   : .~.'~'.~. :   $(tput sgr0)$(tput bold) ___ ___ ___ ___| |_ ___ ___ ___ _ _    ___|_|$(tput sgr0)$(tput setaf 1)"
echo "  ~ (   ) (   ) ~  $(tput sgr0)$(tput bold)|  _| .'|_ -| . | . | -_|  _|  _| | |  | . | |$(tput sgr0)$(tput setaf 1)"
echo " ( : '~'.~.'~' : ) $(tput sgr0)$(tput bold)|_| |__,|___|  _|___|___|_| |_| |_  |  |  _|_|$(tput sgr0)$(tput setaf 1)"
echo "  ~ .~ (   ) ~. ~  $(tput sgr0)$(tput bold)            |_|                 |___|  |_|    $(tput sgr0)$(tput setaf 1)"
echo "   (  : '~' :  )"
echo "    '~ .~~~. ~'"
echo "        '~'"
echo "$(tput sgr0)"
echo "$(tput setaf 2)
`date +"%A, %e %B %Y, %R %Z"`

$(tput sgr0)- Uptime.............: ${UPTIME}
$(tput sgr0)- OS.................: ${OSVER}
$(tput sgr0)- Kernal.............: ${KERNVER}
$(tput sgr0)- PI.................: ${PIVER}
$(tput sgr0)- Updates............: ${UPGRADE_CNT}
$(tput sgr0)- Disk...............: ${DISK}
$(tput sgr0)- Memory.............: ${MEM}
$(tput sgr0)- Load Averages......: ${one}, ${five}, ${fifteen} (1, 5, 15 min)
$(tput sgr0)- Running Processes..: ${PROC_CNT}
$(tput sgr0)- IP Address.........: ${INT_IP_ADDR}

$(tput sgr0)"
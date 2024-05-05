#!/bin/sh
# motd script
# https://zsitko.com/welcome-message-motd-raspberry-pi/
# https://krishna-alagiri.medium.com/raspberry-pi-awesome-custom-motd-db16e0c1902
#
let upSeconds="$(/usr/bin/cut -d. -f1 /proc/uptime)"
let secs=$((${upSeconds}%60))
let mins=$((${upSeconds}/60%60))
let hours=$((${upSeconds}/3600%24))
let days=$((${upSeconds}/86400))

OSVER=`cat /etc/os-release | egrep -o  PRETTY_NAME=.* | sed -E 's/PRETTY_NAME=\"(.+)\"/\1/'`
PIVER=`pinout | egrep Description.*:.* | sed -E 's/Description\s+:\s+(.*)/\1/'`
MEM_TOTAL=`pinout | egrep RAM.*:.* | sed -E 's/RAM\s+:\s+(.*)/total: \1/'`
MEM=`free -gh --si | egrep -o Mem:.* | sed -E 's/\Mem:\s+([0-9\.]+[GMK]?)\s+([0-9\.]+[GMK]?)\s+([0-9\.]+[GMK]?)\s+([0-9\.]+[GMK]?)\s+([0-9\.]+[GMK]?)\s+([0-9\.]+[GMK]?)/used: \2 free: \3/'`
DISK=`df -h / | egrep -o /dev/.* | sed -E 's/\/dev\/[^\s]+\s+([0-9]+[GM]?)\s+([0-9\.]+[GM]?)\s+([0-9\.]+[GM]?).*/total: \1 used: \2 free: \3/'`
UPTIME=`printf "%d days, %02dh%02dm%02ds" "$days" "$hours" "$mins" "$secs"`

# get the load averages
read one five fifteen rest < /proc/loadavg

#clear
echo "$(tput bold)$(tput setaf 2)"
echo "    .~~.   .~~.  "
echo "   '. \ ' ' / .' "
echo "$(tput setaf 1)"
echo "    .~ .~~~..~.   "
echo "   : .~.'~'.~. :  "
echo "  ~ (   ) (   ) ~ "
echo " ( : '~'.~.'~' : )"
echo "  ~ .~ (   ) ~. ~ "
echo "   (  : '~' :  )  "
echo "    '~ .~~~. ~'   "
echo "        '~'      "

echo "$(tput setaf 2)
`date +"%A, %e %B %Y, %r"`
`uname -srmo`

$(tput sgr0)- Uptime.............: ${UPTIME}
$(tput sgr0)- OS.................: ${OSVER}
$(tput sgr0)- PI.................: ${PIVER}
$(tput sgr0)- Disk...............: ${DISK}
$(tput sgr0)- Memory.............: ${MEM_TOTAL} ${MEM}
$(tput sgr0)- Load Averages......: ${one}, ${five}, ${fifteen} (1, 5, 15 min)
$(tput sgr0)- Running Processes..: `ps ax | wc -l | tr -d " "`
$(tput sgr0)- IP Addresses.......: `hostname -I | /usr/bin/cut -d " " -f 1` and `wget -q -O - http://icanhazip.com/ | tail`

$(tput sgr0)"

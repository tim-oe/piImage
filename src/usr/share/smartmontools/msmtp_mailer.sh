#! /bin/sh
#
# custom mailer script for use with msmtp
#

set -e

#env  > /var/log/smartd.test.log

export PATH="$PATH:/usr/local/bin:/usr/bin:/bin"
MAILER_CMD=msmtp

# Format message
fullmessage=`
  echo "Subject: $SMARTD_SUBJECT"
  echo
  echo "$SMARTD_FULLMESSAGE"
`

echo "$fullmessage" | "$MAILER_CMD" -t -- $SMARTD_ADDRESS

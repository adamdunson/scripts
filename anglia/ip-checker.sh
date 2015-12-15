#!/bin/bash

function whatismyip {
  #curl -s -L http://checkip.dyndns.com/ | sed -r 's/^.*\b([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})\b.*$/\1/'
  curl -s http://ifconfig.me
}

#MAILTO=""
IP="$([ -f ip.txt ] && tail -1 ip.txt)"
CURRIP="$(whatismyip)"

if [ "$CURRIP" != "" -a "$CURRIP" != "$IP" ]; then
  echo "$CURRIP" >> ip.txt
  mail -s "IP Address Changed!" "$MAILTO" <<EOF
New IP is: $CURRIP
EOF
fi

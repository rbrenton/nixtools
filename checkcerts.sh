#!/bin/bash
HOSTSFILE=hosts.txt

if [ ! -e $HOSTSFILE ]
then
  echo "Missing $HOSTSFILE"
  exit 1
fi

for host in `cat $HOSTSFILE`
do
  echo -n "$host	"
  date=$(echo | openssl s_client -connect $host:443 2> /dev/null | openssl x509 -noout -dates 2> /dev/null | egrep ^notAfter= | sed "s/notAfter=//")
  if [ ! -z "$date" ]
  then
    tmp="$(echo $date | cut '-d ' -f1,2), $(echo $date | cut '-d ' -f4) $(echo $date | cut '-d ' -f3)"
    echo -n $(date --date "$tmp" "+%Y-%m-%d")
  fi
  echo ""
done


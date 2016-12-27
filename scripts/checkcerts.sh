#!/bin/bash

usage() {
  cat << EOF
Usage: $0 [OPTION]... [HOSTNAME]
Check expiration of remote SSL/TLS certificates.

Arguments:
  -f HOSTFILE  The file containing hostnames to check (one per line).
  -h           This help message.

HOSTNAME is the host to check if -f is not provided.
EOF
}

HOSTS_FILE=""

while getopts "f:h" arg; do
  case $arg in
    f) HOSTS_FILE="$OPTARG" ;;
    h) usage ; exit ;;
  esac
done
shift $((OPTIND-1))


checkhost() {
  local date
  local host=$1
  local tmp

  echo -n "$host	"
  date=$(echo | openssl s_client -connect $host:443 2> /dev/null | openssl x509 -noout -dates 2> /dev/null | egrep ^notAfter= | sed "s/notAfter=//")
  if [ ! -z "$date" ]
  then
    tmp="$(echo $date | cut '-d ' -f1,2), $(echo $date | cut '-d ' -f4) $(echo $date | cut '-d ' -f3)"
    echo -n $(date --date "$tmp" "+%Y-%m-%d")
  fi
  echo ""
}

if [ ! -z "$HOSTS_FILE" ]
then
  if [ ! -e "$HOSTS_FILE" ]
  then
    echo "Missing $HOSTS_FILE"
    exit 1
  fi

  for host in `cat "$HOSTS_FILE"`
  do
    checkhost $host
  done
elif [ ! -z "$@" ]
then
  checkhost $@
else
  usage
fi

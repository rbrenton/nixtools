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

checkhost() {
  local date
  local host=$1
  local tmp
  local status

  echo -n "$host"
  echo -n "	" # tab
  date=$(echo | timeout 5 openssl s_client -connect $host:443 2> /dev/null | openssl x509 -noout -dates 2> /dev/null | egrep ^notAfter= | sed "s/notAfter=//")

  if [ -z "$date" ]
  then
    echo -n "	" # tab
    status="UNKNOWN"
  else
    echo -n $(date --date="$date" '+%Y-%m-%d')
    echo -n "	" # tab

    ts=$(date --date="$date" '+%s')
    now=$(date '+%s')

    if [ $now -ge $ts ]
    then
      status="EXPIRED"
    else
      tmp=$(curl --connect-timeout 3 "https://$host" 2>&1 1> /dev/null | egrep "^curl:")
      if [ ! -z "$tmp" ]
      then
        status="ERROR - $tmp"
      else
        status="valid"
      fi
    fi
  fi

  echo "$status"
}

main() {
  HOSTS_FILE=""

  while getopts "f:h" arg; do
    case $arg in
      f) HOSTS_FILE="$OPTARG" ;;
      h) usage ; exit ;;
    esac
  done
  shift $((OPTIND-1))


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
}

main

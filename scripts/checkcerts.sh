#!/bin/bash

HOSTS_ERROR=""
HOSTS_EXPIRED=""
HOSTS_UNKNOWN=""
HOSTS_VALID=""

HOSTS_FILE=""
FORMAT="summary"

usage() {
  cat << EOF
Usage: $0 [OPTION]... [HOSTNAME]
Check expiration of remote SSL/TLS certificates.

Arguments:
  -f HOSTFILE  The file containing hostnames to check (one per line).
  -h           This help message.
  -t           Tab delimited output.
  -s           Summarized output.


HOSTNAME is the host to check if -f is not provided.
EOF
}

output_tab() {
  if [ "$FORMAT" == "tab" ]; then echo "$@"; fi
}

output_summary() {
  if [ "$FORMAT" == "summary" ]; then echo "$@" | sed 's/\\n/\n/g'; fi
}

checkhost() {
  local date
  local host=$1
  local tmp
  local status

  output_tab -n "$host"
  output_tab -n "	" # tab
  date=$(echo | timeout 5 openssl s_client -connect $host:443 2> /dev/null | openssl x509 -noout -dates 2> /dev/null | egrep ^notAfter= | sed "s/notAfter=//")

  if [ -z "$date" ]
  then
    output_tab -n "	" # tab
    status="UNKNOWN"
    HOSTS_UNKNOWN="${HOSTS_UNKNOWN}${host}\n"
  else
    ymd=$(date --date="$date" '+%Y-%m-%d')
    output_tab -n $ymd
    output_tab -n "	" # tab

    ts=$(date --date="$date" '+%s')
    now=$(date '+%s')

    if [ $now -ge $ts ]
    then
      status="EXPIRED"
      HOSTS_EXPIRED="${HOSTS_EXPIRED}${ymd} ${host}\n"
    else
      tmp=$(curl --connect-timeout 3 "https://$host" 2>&1 1> /dev/null | egrep "^curl:")
      if [ ! -z "$tmp" ]
      then
        status="ERROR - $tmp"
        HOSTS_ERROR="${HOSTS_ERROR}${ymd} ${host}  ${tmp}\n"
      else
        status="valid"
        HOSTS_VALID="${HOSTS_VALID}${ymd} ${host}\n"
      fi
    fi
  fi

  output_tab "$status"
}


while getopts "f:hst" arg; do
  case $arg in
    f) HOSTS_FILE="$OPTARG" ;;
    t) FORMAT="tab" ;;
    s) FORMAT="summary" ;;
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
  exit
fi


# Output summary.
if [ ! -z "$HOSTS_VALID" ]
then
  output_summary "\n-- Valid Certificates --\n$HOSTS_VALID"
fi

if [ ! -z "$HOSTS_EXPIRED" ]
then
  output_summary "\n-- Expired Certificates --\n$HOSTS_EXPIRED"
fi

if [ ! -z "$HOSTS_UNKNOWN" ]
then
  output_summary "\n-- Unknown --\n$HOSTS_UNKNOWN"
fi

if [ ! -z "$HOSTS_ERROR" ]
then
  output_summary "\n-- Errors --\n$HOSTS_ERROR"
fi

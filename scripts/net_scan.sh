#!/bin/bash

# Command line input
ARGC=$((BASH_ARGC+0))
ARGV0=$0
ARGV1=$1
ARGV2=$2

# Displays syntax help
function usage {
  if [[ ! -z "$1" ]]
  then
    echo "$ARGV0: error: $1"
    echo
  fi

  echo "Usage: $ARGV0 <network> [-mtu]"
  echo "Quickly scan network and display active IPs."
  echo
  echo "Options"
  echo "  -mtu                       probe remote mtu"
  echo
  echo "(e.g. $ARGV0 192.168.1.0/24 -mtu)"
  echo
  echo "Report bugs at https://github.com/rbrenton/nixtools/issues"

  exit
}

# Scans network
function scan {
  local base10 base10_end do_mtu=$2 mask network=$1 pattern re255="([01]?[0-9]{1,2}|2([0-4][0-9]|5[0-5]))" re32="([0-2]?[0-9]|3[0-2])"

  # Parse network input
  pattern="^${re255}\.${re255}\.${re255}\.${re255}/${re32}$"
  if [[ ! $network =~ $pattern ]]
  then
    usage "Invalid network syntax."
  fi

  # Set starting ip
  base10=`ip4_to_base10 ${BASH_REMATCH[1]}.${BASH_REMATCH[3]}.${BASH_REMATCH[5]}.${BASH_REMATCH[7]}`
  bits=$((32 - BASH_REMATCH[9]))
  base10=$((base10 >> bits << bits))

  # Set end ip
  base10_end=$((base10 + 2**bits))

  # Iterate start+1 to end-1
  base10=$((base10+1))
  while [[ $base10 -lt $((base10_end-1)) ]]
  do
    ip4=`base10_to_ip4 $base10`
    scan_ip $ip4 $do_mtu 2> /dev/null
    base10=$((base10+1))
  done
}

# Convert ip4 to base10
function ip4_to_base10 {
  local ip=$1 pattern re255="([01]?[0-9]{1,2}|2([0-4][0-9]|5[0-5]))"

  # Parse IP input
  pattern="^${re255}\.${re255}\.${re255}\.${re255}$"
  if [[ ! $ip =~ $pattern ]]
  then
    return 1
  fi

  echo -n $((BASH_REMATCH[1] * 16777216 + BASH_REMATCH[3] * 65536 + BASH_REMATCH[5] * 256 + BASH_REMATCH[7]))
}

# Convert base10 to ip4
function base10_to_ip4 {
  local dec=$1 ip interval octet

  for interval in `echo 16777216 65536 256 1`
  do
    octet=$(( dec / interval ))
    dec=$(( dec - octet * interval ))
    if [[ ! -z "$ip" ]]
    then
      ip=${ip}.
    fi
    ip=$ip$octet
  done

  echo -n $ip
}

# Scan ip
function scan_ip {
  local do_mtu=$2 ip=$1 mac="" ms="" mtu=""

  # Ping host
  ms=`ping_ip $ip`
  if [[ -z "$ms" ]]
  then
    # Host down
    return
  fi

  # Host up
  echo -n "pong ip=$ip ms=$ms"

  # Find mac
  echo -n " mac="
  mac=`arp -an $ip|egrep -io "([a-f0-9]{2}:){5}[a-f0-9]{2}"`
  echo -n $mac

  # Find mtu
  if [[ ! -z "$do_mtu" ]]
  then
    echo -n " mtu="
    echo -n $(find_mtu $ip)
    #mtu=`find_mtu $ip`
    #cho -n $mtu
  fi

  echo
}

# Find mtu for ip
function find_mtu {
  local interval=0 ip=$1 mtu_found=0 mtu_cur=0 mtu_max=131072

  # Binary search for mtu
  for interval in `echo 65536 32768 16384 8192 4096 2048 1024 512 256 128 64 32 16 8 4 2 1`
  do
    if [[ $mtu_cur -le $mtu_found ]]
    then
      mtu_cur=$((mtu_cur + interval))
    else
      mtu_cur=$((mtu_cur - interval))
    fi

    for i in `seq 1 5`
    do
      if [[ ! -z "`ping_ip $ip $mtu_cur`" ]]
      then
       mtu_found=$mtu_cur
       break
      fi
    done
  done

  echo -n $mtu_found
}

# Ping ip
function ping_ip {
  # 20 (IP) + 8 (ICMP)
  local header_bytes=28 ip=$1 ms="0" mtu=$(($2+0)) pattern="" result="" timeout=250

  # Sanity check size
  if [[ $mtu -le 0 ]]
  then
    mtu=$((56+28))
  fi

  # Set timeout in ms
  if [[ $mtu -gt 8192 ]]
  then
    timeout=700
  elif [[ $mtu -gt 2048 ]]
  then
    timeout=600
  elif [[ $mtu -gt 512 ]]
  then
    timeout=500
  fi

  # Prefer fping if available
  if [[ ! -z "`which fping`" ]]
  then
    result=`fping -c 1 -t $timeout -b $((mtu-header_bytes)) $1 2> /dev/null`
    pattern=" bytes, ([0-9.]+) ms "
  else
    timeout=$((timeout / 1000 + 1))
    result=`ping $1 -c 1 -W $timeout -M do -s $((mtu-header_bytes)) | grep time=`
    pattern="time=([0-9.]+) ms"
  fi

  # Non-empty result means successful ping
  if [[ ! -z "$result" ]]
  then
    if [[ $result =~ $pattern ]]
    then
      ms="${BASH_REMATCH[1]}"
    fi
    echo -n $ms
    return 0
  fi

  return 1
}

# __main__
if [[ $ARGC -lt 1 || $ARGC -gt 2 || $ARGC -eq 2 && $ARGV2 != "-mtu" ]]
then
  usage
fi

scan $ARGV1 $ARGV2

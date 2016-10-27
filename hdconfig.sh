#!/bin/bash

trim() {
  read str

  if [ ! -z "$1" ]
  then
    str=$1
  fi

  echo -n "$str" | sed -re 's/([\r\n]|^[[:space:]]*|[[:space:]]*$)//g'
}

for d in `ls /sys/block/|grep ^sd`
do
  rot=$(cat /sys/block/$d/queue/rotational)

  # SSD, probably.
  if [ $rot == "0" ]
  then
    /sbin/hdparm -a1024 /dev/$d > /dev/null
    echo deadline > /sys/block/$d/queue/scheduler   #default:deadline
    echo 0        > /sys/block/$d/queue/add_random  #default:0
    echo 2        > /sys/block/$d/queue/rq_affinity #default:1
  fi

  # Spinning disk.
  if [ $rot == "1" ]
  then
    /sbin/hdparm -a128 /dev/$d > /dev/null
    echo noop     > /sys/block/$d/queue/scheduler   #default:deadline
    echo 0        > /sys/block/$d/queue/add_random  #default:1
    echo 2        > /sys/block/$d/queue/rq_affinity #default:1
  fi

  # Output settings in effect.
  echo -n "$d "
  for i in $(echo rotational scheduler add_random rq_affinity)
  do
    echo -n "$i=$(cat /sys/block/$d/queue/$i | trim), "
  done
  echo -n "readahead=$(/sbin/hdparm -a /dev/$d | grep = | cut -d= -f2 | trim) "
  echo ""

done

#!/bin/bash
SHADOW=/etc/shadow

# Check syntax.
if [[ $BASH_ARGC != 2 ]]; then
  echo "Usage: $0 <user> <hash>";
  exit 1;
fi

# Locate user.
ENTRY=`egrep "^$1:" $SHADOW`
if [[ $ENTRY == '' ]]; then
  echo "User not found: $1";
  exit 2;
fi

# Check if hash already set.
ENTRY=`egrep "^$1:[*]?:" $SHADOW`
if [[ $ENTRY == '' ]]; then
  echo "Hash already set.";
  exit 3;
fi

# Set hash.
echo "Setting hash for user $1 to $2";
RESULT=`sed -i.bak s/^$1:[^:]*:/$1:$2:/ $SHADOW`

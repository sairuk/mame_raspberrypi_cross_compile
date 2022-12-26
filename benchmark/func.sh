#!/bin/bash

usage() {
  echo "Usage $0" 
  echo "-h this help"
  echo "-i /path/to/gameslist.txt"
  echo "-p profile (default: bench)"
  echo "-m mode (inactive)"
  echo "-l list profiles"
  exit 0

}

config() {
    # Source config
    [ ! -f ${TDIR}/config.ini ] && cp ${TDIR}/config.ini.dist ${TDIR}/config.ini
    source "${TDIR}/config.ini"
}

mamever() {
    # Get MAME version
    export MAMEVER=$(${MAMEDIR}/mame -version | awk '{print $1}')
    [ -z "$MAMEVER" ] && echo "Failed to set MAMEVER, exiting" && exit 1
    echo "MAMEVER set to $MAMEVER"
}

model() {
    # Get model
    MFILE=/proc/device-tree/model
    MODEL="Generic"
    [ -f $MFILE ] && MODEL=$(cat /proc/device-tree/model 2>/dev/null)
    export MODEL
}

arch() {
    # Get arch
    export MARCH=$(uname -m)
}

list_profiles() {
    echo "Available profiles:"
    find "${1}" -type f
    exit 0
}
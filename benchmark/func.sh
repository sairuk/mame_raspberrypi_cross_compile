#!/bin/bash

usage() {
  echo
  echo "${0} /path/to/gameslist.txt"
  echo
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
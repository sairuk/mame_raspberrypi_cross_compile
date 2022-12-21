#!/bin/bash

set -x

usage() {
  echo
  echo "${0} /path/to/gameslist.txt"
  echo
}

[ -z "${1}" ] && usage && exit 1
[ ! -f "${1}" ] && echo -e "\n${1} not found!\n" && usage && exit 1

TDIR=$( dirname "${0}" )

# Source config
[ ! -f ${TDIR}/config.ini ] && cp ${TDIR}/config.ini.dist ${TDIR}/config.ini
source "${TDIR}/config.ini"

# Enable dynamic recompilation for x86 architectures only
# Disable it for everything else, as it's not supported by MAME yet
export MARCH=$(uname -m)
case "${MARCH}" in
x86_64)
  unset NODRC
  ;;
i686)
  unset NODRC
  ;;
i386)
  unset NODRC
  ;;
*)
  export NODRC="-nodrc"
  ;;
esac

MAMEVER=$(${MAMEDIR}/mame -version | awk '{print $1}')
[ -z "$MAMEVER" ] && echo "Failed to set MAMEVER, exiting"

echo "MAMEVER set to $MAMEVER"


# Build binary with all path options
export MBIN="${MAMEDIR}/mame -homepath ${MAMEDIR} -rompath ${MAMEDIR}/roms;${MAMEDIR}/chd -cfg_directory ${MAMEDIR}/cfg -nvram_directory ${MAMEDIR}/nvram ${NODRC}"

# Set the download URL for the NVRAM files
export MURL="https://raw.githubusercontent.com/danmons/mame_raspberrypi_cross_compile/main/benchmark/files"

# Create MAME dirs if missing, handle user create symlinks as well
for DIR in roms chd cfg nvram
do
  if [ ! -L ${MAMEDIR}/${DIR} ]
  then
    [ ! -d ${MAMEDIR}/${DIR} ] && mkdir -p ${MAMEDIR}/$DIR > /dev/null
  fi
done

# Create output dirs if missing
mkdir -p "${TDIR}/log" 2>/dev/null

# Read the list of ROMs
# Benchmark only the ones with missing results
# To re-benchmark, delete the output log file
cat "${1}" | while read MROM
do
  HASFPS=$(grep -E "^${MAMEVER}.*Average.*" "${TDIR}/log/${MROM}.log" 2>/dev/null)
  if [ -z "${HASFPS}" ]
  then
    echo Benchmarking "${MROM}"

    # create log dir structure
    LOGDIR=${TDIR}/log/${MAMEVER}/${MROM}
    [ ! -d ${LOGDIR} ] && mkdir -p ${LOGDIR}

    unset NEEDSNVRAM
    NEEDSNVRAM=$( grep ^"${MROM}"$ "${TDIR}/lists/nvram.txt" )
    if [ -n "${NEEDSNVRAM}" ]
    then
      echo "${MROM} requires NVRAM files to benchmark accurately, downloading them..."
      cd "${MAMEDIR}/nvram"
      aria2c --allow-overwrite=true "${MURL}/nvram/${MROM}.7z"
      7za x -aoa "${MROM}.7z"
      cd -
      cd "${MAMEDIR}/cfg"
      aria2c --allow-overwrite=true "${MURL}/cfg/${MROM}.cfg"
      cd -
    fi
    # Flush disk buffers before and after in case we crash, so we can at least save the logs
    sync

    # run
    RESULT=$( ${MBIN} -bench ${BENCHTIME} "${MROM}" 2> "${LOGDIR}/error.log" )

    # track progress (if available)
    echo "$RESULT" | grep -Ev "^Average.*" | sed -r 's/^\[SPEED\]\s// ' >"${LOGDIR}/progress.log"
    PROG_SIZE=$(stat -c %s "${LOGDIR}/progress.log")
    [ $PROG_SIZE -eq 0 ] && rm "${LOGDIR}/progress.log"

    # collect average
    echo "$RESULT" | grep -E "^Average.*" &>/dev/null
    EXITCODE=$?
    if [ $EXITCODE -eq 0 ]
    then
      AVERAGE=$(echo $RESULT | grep -Eo "Average.*")
      echo "$AVERAGE" >"${LOGDIR}/average.log"
      sync
      sleep 3
    else
      # handle failed run
      echo "Failed to benchmark ${MROM} (exit-code: $EXITCODE)"
      ERROR_SIZE=$(stat -c %s "${LOGDIR}/error.log")
      [ $ERROR_SIZE -eq 0 ] && rm "${LOGDIR}/error.log"
    fi
  else
    echo "${MROM}" already has benchmark results for $MAMEVER in "${LOGDIR}/average.log"
  fi
done

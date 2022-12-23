#!/bin/bash
TDIR=$( dirname "${0}" )
source "${TDIR}/func.sh"
config

DATA=${1:-""}
[ -z "${DATA}" ] && usage && exit 1
[ ! -f "${DATA}" ] && echo -e "\n${DATA} not found!\n" && usage && exit 1

# Gather info
mamever
model
arch

# Enable dynamic recompilation for x86 architectures only
# Disable it for everything else, as it's not supported by MAME yet
case "${MARCH}" in
x86_64|i686|i386)
  unset NODRC
  ;;
*)
  export NODRC="-nodrc"
  ;;
esac

# Build binary with all path options
export MBIN="${MAMEDIR}/mame -homepath ${MAMEDIR} -rompath ${MAMEDIR}/roms;${MAMEDIR}/chd -cfg_directory ${MAMEDIR}/cfg -nvram_directory ${MAMEDIR}/nvram ${NODRC}"

# Create MAME dirs if missing, handle user create symlinks as well
for DIR in roms chd cfg nvram
do
  [ ! -L "${MAMEDIR}/${DIR}" ] || [ ! -d "${MAMEDIR}/${DIR}" ] && mkdir -p "${MAMEDIR}/${DIR}" > /dev/null
done

# Create output dirs if missing
mkdir -p "${TDIR}/${LOGBASE}" 2>/dev/null

# Read the list of ROMs
# Benchmark only the ones with missing results
# To re-benchmark, delete the output log file
cat "${DATA}" | while read MROM
do

  # create log dir structure
  LOGDIR=${TDIR}/log/${MAMEVER}/${MROM}
  HASFPS=$(grep -E "Average.*" "${LOGDIR}/${AVERAGELOG}" 2>/dev/null)
  LASTRUNTIME=$(cat "${LOGDIR}/${RUNTIMELOG}" 2>/dev/null || echo "0")
  
  if [ -z "${HASFPS}" ] || [ ${BENCHTIME} -ne ${LASTRUNTIME} ]
  then
    echo Benchmarking "${MROM} for ${BENCHTIME}s"

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

    # update MBIN
    MBINU="${MBIN} -bench ${BENCHTIME} ${MROM}"
    echo "${MBINU}" > "${LOGDIR}/cmdline"

    # run
    RESULT=$( ${MBINU} 2> "${LOGDIR}/${ERRORLOG}" )

    # log runtime
    echo "$BENCHTIME" > "${LOGDIR}/${RUNTIMELOG}"

    # track progress (if available)
    echo "$RESULT" | grep -Ev "^Average.*" | sed -r 's/^\[SPEED\]\s// ' >"${LOGDIR}/${PROGRESSLOG}"
    PROG_SIZE=$(stat -c %s "${LOGDIR}/${PROGRESSLOG}")
    [ $PROG_SIZE -eq 0 ] && rm "${LOGDIR}/${PROGRESSLOG}"

    # collect average
    echo "$RESULT" | grep -E "^Average.*" &>/dev/null
    EXITCODE=$?
    if [ $EXITCODE -eq 0 ]
    then
      AVERAGE=$(echo $RESULT | grep -Eo "Average.*")
      echo "$AVERAGE" >"${LOGDIR}/${AVERAGELOG}"
      sync
      sleep 3
    else
      # handle failed run
      echo "Failed to benchmark ${MROM} (exit-code: $EXITCODE)"
      ERROR_SIZE=$(stat -c %s "${LOGDIR}/${ERRORLOG}")
      [ $ERROR_SIZE -eq 0 ] && rm "${LOGDIR}/${ERRORLOG}"
    fi
  else
    echo "${MROM}" already has benchmark results for $MAMEVER in "${LOGDIR}/${AVERAGELOG}"
  fi

done

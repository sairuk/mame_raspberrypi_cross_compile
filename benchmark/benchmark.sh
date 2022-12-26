#!/bin/bash
TDIR=$( dirname "${0}" )
source "${TDIR}/func.sh"
config

DATA=""
FORCE=0

OPTSTRING="hlfi:p:m:"
while getopts $OPTSTRING ARG
do
  case $ARG in
    h)
      usage
      ;;
    i)
      DATA="${OPTARG}"
      ;;
    p)
      PROFILE="${OPTARG}"
      ;;
    m)
      MODE="${OPTARG}"
      ;;
    l)
      list_profiles "${PROFILEBASE}"
      ;;
    f)
      FORCE=1
      ;;
    *)
      usage
      ;;
  esac
done


# check data source is populated
REQFAIL=0
[ -z "${DATA}"        ] && echo "Did not pass a gamelist"                     && REQFAIL=1
[ -z "${PROFILE}"     ] && echo "Profile is not set"                          && REQFAIL=1
[ $REQFAIL -ne 0      ] && usage && exit $REFAIL

[ ! -f "${PROFILE}"   ] && echo "requested profile does not exist"            && REQFAIL=1
[ ! -f "${DATA}"      ] && echo "${DATA} not found!"                          && REQFAIL=1
[ $REQFAIL -ne 0      ] && echo "Requirements failed, see previous messages"  && exit $REFAIL

# Gather info
mamever
model
arch

# Create the MBIN array to store runtime settings
declare -a MBIN

# source default benchmarking
source ${PROFILE}

## bench overrides
# version
[ -f ${PROFILEBASE}/${MAMEVER} ] && source ${PROFILEBASE}/${MAMEVER}

# Enable dynamic recompilation for x86 architectures only
# Disable it for everything else, as it's not supported by MAME yet
case "${MARCH}" in
x86_64|i686|i386)
  MBIN+="-drc "
  ;;
*)
  MBIN+="-nodrc "
  ;;
esac

# Create MAME dirs if missing, handle user create symlinks as well
for DIR in roms chd cfg nvram
do
  [ ! -L "${MAMEDIR}/${DIR}" ] || [ ! -d "${MAMEDIR}/${DIR}" ] && mkdir -p "${MAMEDIR}/${DIR}" > /dev/null
done

# Create output dirs if missing
mkdir -p "${TDIR}/${LOGBASE}" 2>/dev/null

# get basename for profile
PROFILENAME=$(basename $PROFILE)

# Read the list of ROMs
# Benchmark only the ones with missing results
cat "${DATA}" | while read MROM
do

  # create log dir structure
  LOGDIR=${TDIR}/log/${MAMEVER}/${MROM}
  HASFPS=$(grep -E "Average.*" "${LOGDIR}/${PROFILENAME}/001/${AVERAGELOG}" 2>/dev/null)
  LASTRUNTIME=$(cat "${LOGDIR}/${PROFILENAME}/001/${RUNTIMELOG}" 2>/dev/null || echo "0")
  
  if [ $FORCE -eq 1 ] || [ -z "${HASFPS}" ] || [ ${BENCHTIME} -ne ${LASTRUNTIME} ]
  then

    # import overrides per rom
    [ -f ${PROFILEBASE}/${MROM} ] && source ${PROFILEBASE}/${MROM}
    [ -f ${PROFILEBASE}/${MAMEVER}-${MROM} ] && source ${PROFILEBASE}/${MAMEVER}-${MROM}

    echo Benchmarking "${MROM} for ${BENCHTIME}s (profile: ${PROFILENAME}}"

    [ ! -d "${LOGDIR}/${PROFILENAME}" ] && mkdir -p "${LOGDIR}/${PROFILENAME}"

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
    MBINU="${MBIN} ${MROM}"
    echo "${MBINU}" > "${LOGDIR}/${PROFILENAME}/cmdline"

    RUN=1
    while [ $RUN -le $RUNS ]
    do
      echo "Executing run $RUN/$RUNS"

      LOGDIRRUN="${LOGDIR}/${PROFILENAME}/$( printf '%03d' $RUN )"
      [ ! -d "${LOGDIRRUN}" ] && mkdir -p "${LOGDIRRUN}"

      # run
      RESULT=$( ${MBINU} 2> "${LOGDIRRUN}/${ERRORLOG}" )

      # log runtime
      echo "$BENCHTIME" > "${LOGDIRRUN}/${RUNTIMELOG}"


      echo "$PROFILENAME" > "${LOGDIRRUN}/${PROFILELOG}"

      # track progress (if available)
      echo "$RESULT" | grep -Ev "^Average.*" | sed -r 's/^\[SPEED\]\s// ' >"${LOGDIRRUN}/${PROGRESSLOG}"
      PROG_SIZE=$(stat -c %s "${LOGDIRRUN}/${PROGRESSLOG}")
      [ $PROG_SIZE -eq 0 ] && rm "${LOGDIRRUN}/${PROGRESSLOG}"

      # collect average
      echo "$RESULT" | grep -E "^Average.*" &>/dev/null
      EXITCODE=$?
      if [ $EXITCODE -eq 0 ]
      then
        AVERAGE=$(echo $RESULT | grep -Eo "Average.*")
        echo "$AVERAGE" >"${LOGDIRRUN}/${AVERAGELOG}"
        sync
        sleep 3
        RUN=$(( $RUN + 1 ))
      else
        # handle failed run
        echo "Failed to benchmark ${MROM} (exit-code: $EXITCODE)"
        ERROR_SIZE=$(stat -c %s "${LOGDIRRUN}/${ERRORLOG}")
        [ $ERROR_SIZE -eq 0 ] && rm "${LOGDIRRUN}/${ERRORLOG}"
        RUN=$(( $RUNS + 1 ))
      fi

    done
  else
    echo "${MROM}" already has benchmark results for $MAMEVER in "${LOGDIR}/${PROFILENAME}/001/${AVERAGELOG}"
  fi

done

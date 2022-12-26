#!/bin/bash
TDIR=$( dirname "${0}" )
source "${TDIR}/func.sh"
config

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
    l)
      list_profiles "${PROFILEBASE}"
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

# get gamelist name based on underscore split
GAMELIST=$(basename $(echo "${DATA}" | cut -d'_' -f2 ) .txt)

# Gather info
mamever
model
arch

# get basename for profile
PROFILENAME=$(basename $PROFILE)

# Create output dirs if missing
OUTDIR="${TDIR}/${RESULTBASE}/${MAMEVER}"
mkdir -p "${OUTDIR}" 2>/dev/null

# Check all results exist
RUN=1
while read -r MROM
do
    while [ $RUN -le $RUNS ]
    do
      echo "Checking Run $RUN/$RUNS"
      LOGDIR="${TDIR}/${LOGBASE}/${MAMEVER}/${MROM}/${PROFILENAME}/$( printf '%03d' $RUN )"
      MEXIST=$( grep -E "^Average.*" "${LOGDIR}/${AVERAGELOG}" 2>/dev/null )
      if [ -z "${MEXIST}" ]
      then
        echo "Results missing"
        echo "Please re-run ${TDIR}/benchmark.sh ${DATA}"
        exit 1
      fi
      RUN=$(( $RUN + 1 ))
    done
done < "${DATA}"


echo "Renaming old results if they exist..."
mv -vf "${OUTDIR}/${GAMELIST}_${PROFILENAME}_${AVGRESULTS}" "${OUTDIR}/${GAMELIST}_${PROFILENAME}_results_average_$(date --iso-8601=s).csv" 2>/dev/null
mv -vf "${OUTDIR}/${GAMELIST}_${PROFILENAME}_${PROGRESULTS}" "${OUTDIR}/${GAMELIST}_${PROFILENAME}_results_progressive_$(date --iso-8601=s).csv" 2>/dev/null

  # Build CSV file
  echo 'Version,Arch,Model,ROM,Percentage,Time,Run' > "${OUTDIR}/${GAMELIST}_${PROFILENAME}_${AVGRESULTS}"
  echo 'Version,Arch,Model,ROM,Percentage,Time,%?,%Curr,%Avg,Sec,Run' > "${OUTDIR}/${GAMELIST}_${PROFILENAME}_${PROGRESULTS}"

  cat "${DATA}" | while read MROM
  do
    RUN=1
    while [ $RUN -le $RUNS ]
    do
      echo "Processing Run $RUN/$RUNS"
      LOGDIR="${TDIR}/${LOGBASE}/${MAMEVER}/${MROM}/${PROFILENAME}/$( printf '%03d' $RUN )"

      # average
      FPS=$( grep -E "^Average.*"  "${LOGDIR}/${AVERAGELOG}" | tail -n1 | awk '{print $3}' | tr -d '%' )
      echo "${MAMEVER},${MARCH},${MODEL},${MROM},${FPS},${BENCHTIME},${RUN}" >> "${OUTDIR}/${GAMELIST}_${PROFILENAME}_${AVGRESULTS}"

      # progressive
      while read -r LINE
      do
        echo "${MAMEVER},${MARCH},${MODEL},${LINE},${RUN}" >> "${OUTDIR}/${GAMELIST}_${PROFILENAME}_${PROGRESULTS}"
      done < ${LOGDIR}/${PROGRESSLOG}
      RUN=$(( $RUN + 1 ))
    done
  done
echo "Results output to ${OUTDIR}"

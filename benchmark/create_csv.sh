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

# Create output dirs if missing
mkdir -p "${TDIR}/${RESULTBASE}" 2>/dev/null

# Check all results exist
while read -r MROM
do
  LOGDIR=${TDIR}/log/${MAMEVER}/${MROM}
  MEXIST=$( grep -E "^Average.*" "${LOGDIR}/${AVERAGELOG}" 2>/dev/null )
  if [ -z "${MEXIST}" ]
  then
    echo "Results missing"
    echo "Please re-run ${TDIR}/benchmark.sh ${DATA}"
    exit 1
  fi
done < "${DATA}"

echo "Renaming old results if they exist..."
mv -vf "${AVGRESULTS}" "${TDIR}/results/results_average_$(date --iso-8601=s).csv" 2>/dev/null
mv -vf "${PROGRESULTS}" "${TDIR}/results/results_progressive_$(date --iso-8601=s).csv" 2>/dev/null

# Build CSV file
echo 'Version,Arch,Model,ROM,Percentage,Time' > "${AVGRESULTS}"
echo 'Version,Arch,Model,ROM,Percentage,Time,%?,%Curr,%Avg,Sec' > "${PROGRESULTS}"
cat "${DATA}" | while read MROM
do
  LOGDIR=${TDIR}/${LOGBASE}/${MAMEVER}/${MROM}

  # average
  FPS=$( grep -E "^Average.*"  "${LOGDIR}/${AVERAGELOG}" | tail -n1 | awk '{print $3}' | tr -d '%' )
  echo "${MAMEVER},${MARCH},${MODEL},${MROM},${FPS},${BENCHTIME}" >> "${AVGRESULTS}"

  # progressive
  while read -r LINE
  do
    echo "${MAMEVER},${MARCH},${MODEL},${LINE}" >> "${PROGRESULTS}"
  done < ${LOGDIR}/${PROGRESSLOG}
done
  
echo "Results output to ${AVGRESULTS} / ${PROGRESULTS}"

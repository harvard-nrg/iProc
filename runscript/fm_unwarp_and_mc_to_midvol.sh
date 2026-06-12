#!/bin/bash
set -xeou pipefail

MC_IN=${1}
MC_OUT=${2}
TARGET=${3}
FLIRT_OUT=${4}
FLIRT_MAT_OUT=${5}
SCAN_TYPE=${6}
NUMVOL=${7}
OUTDIR=${8}
CODEDIR=${9}
FM_SESSID=${10}
FM_BOLDNO=${11}
MIDVOL=${12}
FMdir=${13}
REGRESSORS_MC_DAT_OUT=${14}
DEST_DIR=${15}
WARP_DIR=${16}
unwarp_direction=${17}
ME=${18}
FDThres=${19}
FDTHRES=${20}
NOFM=${21} # 0 for field mpas, 1 for no field maps
MIDVOL_SEARCH_STRATEGY=${22}
MIDVOL_SEARCH_NITS=${23}
USE_DVARS=${24}
rmfiles=${25:-''}

MIDVOL_UNWARP=${MIDVOL}_unwarp

# Initial Selection of MidVol
fslroi ${MC_IN} ${MC_IN%.nii.gz}_OrigMidVol.nii.gz 'expr ${NUMVOL} / 2' 1  ## specific middle volume selected
echo $((${NUMVOL} / 2)) > ${MC_IN%.nii.gz}_OrigMidVol.txt
OrigMidVol=$((${NUMVOL} / 2))

# calculate FD (framewise displacement) outliers using the same FD threshold for REST and TASK
fsl_motion_outliers -i ${MC_IN} -o ${MC_IN%.nii.gz}_FD${FDTHRES}_outlier_mat.txt -s ${MC_IN%.nii.gz}_FD_vals.txt -p ${MC_IN%.nii.gz}_FD.png --fd -v --thresh=${FDThres} > ${MC_IN%.nii.gz}_fsl_motion_outlier_FD${FDTHRES}_output.txt
grep 'Found spikes at ' ${MC_IN%.nii.gz}_fsl_motion_outlier_FD${FDTHRES}_output.txt > ${MC_IN%.nii.gz}_tmp1.txt

set +e
grep -Eo '[0-9]{1,4}' ${MC_IN%.nii.gz}_tmp1.txt > ${MC_IN%.nii.gz}_FD${FDTHRES}_outlier_num.txt
returncode=$?
set -e

if [ "${returncode}" -eq 0 ]; then
    echo "grep found spikes"
elif [ "${returncode}" -eq 1 ]; then
    echo "grep did not find any spikes"
else
    echo "grep errored with returncode ${returncode}"
    exit "${returncode}"
fi

# making list of outlier volumes
if [[ ! -e ${MC_IN%.nii.gz}_FD${FDTHRES}_outlier_num.txt ]]; then
  echo No Motion Spikes;
  touch ${MC_IN%.nii.gz}_FD${FDTHRES}_outlier_num.txt
fi

# calculate DVARS (derivative of RMS variance) 
# this is typically used in developmental studies
if [[ ! -e ${MC_IN%.nii.gz}_DVARS_vals.txt ]]; then
  fsl_motion_outliers -i ${MC_IN} -o ${MC_IN%.nii.gz}_DVARS_outlier_mat.txt -s ${MC_IN%.nii.gz}_DVARS_vals.txt -p ${MC_IN%.nii.gz}_DVARS.png --dvars -v > ${MC_IN%.nii.gz}_fsl_motion_outlier_DVARS_output.txt
fi
grep 'Found spikes at' ${MC_IN%.nii.gz}_fsl_motion_outlier_DVARS_output.txt > ${MC_IN%.nii.gz}_tmp2.txt
set +e
grep -Eo '[0-9]{1,4}' ${MC_IN%.nii.gz}_tmp2.txt > ${MC_IN%.nii.gz}_DVARS_outlier_num.txt
set -e
touch ${MC_IN%.nii.gz}_DVARS_outlier_num.txt
# Combined and remove duplicate flagged volume outliers into a single matrix
echo checking FD ${FDThres} and DVARS "(default = P75 + 1.5*IQR)" outliers for overlap
sort -u -n ${MC_IN%.nii.gz}_*outlier_num.txt > ${MC_IN%.nii.gz}_ALL_outlier_num.txt
echo ${MC_IN%.nii.gz}_ALL_outlier_num.txt contains all outliers

# calculating percentage of outliers based on FDTHRES
OUTLIER_FILE="${MC_IN%.nii.gz}_FD${FDTHRES}_outlier_num.txt"
if [ "${USE_DVARS}" == "yes" ]; then
  OUTLIER_FILE="${MC_IN%.nii.gz}_ALL_outlier_num.txt"
elif [ "${USE_DVARS}" == "no" ]; then
  OUTLIER_FILE="${MC_IN%.nii.gz}_FD${FDTHRES}_outlier_num.txt"
else
  echo "USE_DVARS must be set to yes or no"
  exit 1
fi

MIDVOL_NO="${OrigMidVol}"
num_outliers=$(cat ${OUTLIER_FILE} | wc -l)
pct=$(bc -l <<< ${num_outliers}/${NUMVOL})
status=$(echo "${pct} >= .2" | bc -l)
if [ "$status" == "1" ]; then
    echo "WARNING: number of outliers (${num_outliers}) is 20% or greater than the total number of volumes (${NUMVOL})"
fi


echo "searching for a non-outlier midvol"
echo "starting with midvol number ${MIDVOL_NO}"
echo "using strategy ${MIDVOL_SEARCH_STRATEGY}"
echo "stopping after ${MIDVOL_SEARCH_NITS} iterations"

found=false

# MIDVOL search strategy 1: move forward $MIDVOL_SEARCH_NITS times
if [ "${MIDVOL_SEARCH_STRATEGY}" == "forward" ]; then 
  for (( i = 1; i <= ${MIDVOL_SEARCH_NITS}; i++ )); do
      set +e
      grep -q -w "${MIDVOL_NO}" "${OUTLIER_FILE}"
      returncode=$?
      set -e
      if [ ${returncode} -eq 0 ]; then
          echo "   ${i}. ${MIDVOL_NO} is an outlier"
      elif [ ${returncode} -eq 1 ]; then
          echo "   ${i}. ${MIDVOL_NO} is not an outlier (stop)"
          found=true
          break
      else
          exit ${returncode}
      fi
      MIDVOL_NO=$((${MIDVOL_NO} + 1))
  done

# MIDVOL search strategy 2: go back-and-forth $MIDVOL_SEARCH_NITS times
elif [ "${MIDVOL_SEARCH_STRATEGY}" == "bidirectional" ]; then
  # helper function for implementing bidirectional search
	next_midvol() {
		local iteration=$1
		local n=$(( (iteration + 1) / 2 ))
		if (( iteration % 2 == 1 )); then
			echo "$n"
		else
			echo "$((-1 * n))"
		fi
	}

    MIDVOL_NO_ORIG=${MIDVOL_NO}
	for (( i = 1; i <= ${MIDVOL_SEARCH_NITS}; i++ )); do
			MIDVOL_NO=$(( ${MIDVOL_NO_ORIG} + $(next_midvol $i) ))
			set +e
			grep -q -w "${MIDVOL_NO}" "${OUTLIER_FILE}"
			returncode=$?
			set -e
			if [ ${returncode} -eq 0 ]; then
					echo "   ${i}. ${MIDVOL_NO} is an outlier"
			elif [ ${returncode} -eq 1 ]; then
					echo "   ${i}. ${MIDVOL_NO} is not an outlier (stop)"
					found=true
					break
			else
					echo "  ${i}. grep failed with code ${returncode}"
					exit ${returncode}
			fi
	done 
else
  echo "Unrecognized MIDVOL_SEARCH_STRATEGY: ${MIDVOL_SEARCH_STRATEGY}"
  exit 1
fi

# quit if no midvol was found
if ! ${found}; then
  echo "unable to find a usable midvol"
  echo "exiting"
  exit 1
fi

echo "using ${MIDVOL_NO} as midvol"

# Create Final MidVol using updated MIDVOL or OrigMidVol
echo ${MIDVOL_NO} > ${MC_IN%.nii.gz}_FinalMidVol.txt

# create motion outlier matrix
OUTLIERMATRIX="${MC_IN%.nii.gz}_FD${FDTHRES}_outlier_matrix.dat"
python ${CODEDIR}/runscript/create_motion_outlier_matrix.py $OUTLIER_FILE $NUMVOL $OUTLIERMATRIX

# motion estimation and correction (within-run alignment)
mcflirt -in ${MC_IN} -out ${MC_OUT} -refvol ${MIDVOL_NO} -mats -plots -rmsrel -rmsabs -report  ## need this but after the specific middle volume has been selected & applying this to that.
fslroi ${MC_OUT} ${MIDVOL} ${MIDVOL_NO} 1 

### ----- 2026.01.16 JS, if no field map, don't unwarp midvol, "unwarp" midvol is just midvol
if [ ${NOFM} -eq 1 ]; then
    echo "------- no field map, copying midvol to midvol unwarp -------"
    cp ${MIDVOL}.nii.gz ${MIDVOL_UNWARP}.nii.gz
else 
    # not going to pass on any warpfiles
    echo "------- field map available, running fm_unw for midvol -------"
    ${CODEDIR}/modwrap.sh 'module load fsl/4.0.3-ncf' 'module load fsl/5.0.4-ncf' ${CODEDIR}/runscript/fm_unw.sh ${FM_SESSID} ${FMdir} ${MIDVOL} ${MIDVOL_UNWARP} ${FM_BOLDNO} ${DEST_DIR} ${WARP_DIR} ${unwarp_direction} ${ME}
fi

flirt -in ${MIDVOL_UNWARP} -ref ${TARGET} -out ${FLIRT_OUT} -omat ${FLIRT_MAT_OUT} -bins 256 -cost corratio -searchrx -180 180 -searchry -180 180 -searchrz -180 180 -dof 12 -interp trilinear 

# look for skip_mc_e1.par if ME (multi-echo) is 1
${CODEDIR}/runscript/p2a.sh ${OUTDIR} ${SCAN_TYPE} ${NUMVOL} ${REGRESSORS_MC_DAT_OUT} ${ME}

if [ -n "$rmfiles" ]; then
    for f in $rmfiles;do
        rm -rf "$f"
    done
fi

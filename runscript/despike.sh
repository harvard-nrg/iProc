#!/bin/sh
set -xeou pipefail
# iProc_STAR # following same structure as calculate_nuisance_params.sh
# Despiking command based on https://afni.nimh.nih.gov/pub/dist/doc/program_help/3dDespike.html
# Lindsay Hanford
# 2026/04/15

RESID_IN=$1
DESPIKE_OUT=$2
OUTDIR=$3
CODEDIR=$4
scratch_base=$5
SCRATCHDIR=$(mktemp --directory --tmpdir=${scratch_base})

cd $SCRATCHDIR

echo "If script fails, run: cd $SCRATCHDIR; rm ${DESPIKE_OUT}+*.BRIK ${DESPIKE_OUT}+*.HEAD"

cpus=$(python -c "import os; cpus=len(os.sched_getaffinity(0)); print(cpus)")
export OMP_NUM_THREADS=${cpus}
echo "OMP_NUM_THREADS=${OMP_NUM_THREADS}"

3dDespike -NEW -prefix ${RESID_IN%.nii.gz}_despike -overwrite -ssave ${DESPIKE_OUT%.nii.gz}_spikiness -q ${RESID_IN}

3dAFNItoNIFTI -prefix ${DESPIKE_OUT%.nii.gz} -overwrite ${DESPIKE_OUT%.nii.gz}+orig.BRIK -float
gzip -f ${DESPIKE_OUT%.nii.gz}.nii

3dAFNItoNIFTI -prefix ${DESPIKE_OUT%.nii.gz}_spikiness -overwrite ${DESPIKE_OUT%.nii.gz}_spikiness+orig.BRIK -float
gzip -f ${DESPIKE_OUT%.nii.gz}_spikiness.nii

# create mean
fslmaths ${DESPIKE_OUT%.nii.gz}.nii.gz -Tmean ${DESPIKE_OUT%.nii.gz}_mean.nii.gz

# create mask
fslmaths ${DESPIKE_OUT%.nii.gz}_mean.nii.gz -bin ${DESPIKE_OUT%.nii.gz}_mask.nii.gz

# Erroring as empty directory - directory not used
rm -r ${SCRATCHDIR}
rm ${DESPIKE_OUT%.nii.gz}*+orig.BRIK
rm ${DESPIKE_OUT%.nii.gz}*+orig.HEAD

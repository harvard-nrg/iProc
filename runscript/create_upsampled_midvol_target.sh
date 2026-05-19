#!/bin/bash 
set -xeou pipefail

SUB=${1}
BNAME=${2}
TEMPLATE_DIR=${3}
RES_STR=${4}
outfile=${5}
rmfiles=${6:-''}

if [ "$RES_STR" = "1p2i" ]; then
	flirt -in ${TEMPLATE_DIR}/${SUB}_D01_${BNAME}_midvol_unwarp.nii.gz -applyisoxfm 1.2 -nosearch -out ${outfile} -ref ${TEMPLATE_DIR}/${SUB}_D01_${BNAME}_midvol_unwarp.nii.gz
else
	flirt -in ${TEMPLATE_DIR}/${SUB}_D01_${BNAME}_midvol_unwarp.nii.gz -applyisoxfm 2 -nosearch -out ${outfile} -ref ${TEMPLATE_DIR}/${SUB}_D01_${BNAME}_midvol_unwarp.nii.gz
fi

ln -sf ${outfile} $TEMPLATE_DIR/${SUB}_midvol_unwarp_${RES_STR}.nii.gz

if [ -n "$rmfiles" ]; then
    for f in $rmfiles;do
        rm -rf "$f"
    done
fi

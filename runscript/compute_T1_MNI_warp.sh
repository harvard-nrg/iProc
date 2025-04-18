#!/bin/bash
set -xeou pipefail
TARGDIR=${1}
invwarp_out=${2}
ATLAS=${3}
ATLASB=${4}
ATLASBM=${5}
SESST=${6}

#TODO: should this be there?
fslswapdim ${TARGDIR}/mpr_reorient_brain.nii.gz x -z y ${TARGDIR}/mpr_brain.nii.gz

flirt -in ${TARGDIR}/mpr_brain -ref ${ATLASB} -out ${TARGDIR}/mpr_brain_mni -omat ${TARGDIR}/mpr_brain_to_mni.mat -bins 256 -cost corratio -searchrx -180 180 -searchry -180 180 -searchrz -180 180 -dof 12 -interp trilinear

fnirt --in=${TARGDIR}/mpr --iout=${TARGDIR}/anat_mni_underlay --ref=${ATLAS} --refmask=${ATLASBM} --aff=${TARGDIR}/mpr_brain_to_mni.mat --cout=${TARGDIR}/mpr_to_mni_FNIRT.mat

invwarp -w ${TARGDIR}/mpr_to_mni_FNIRT.mat.nii.gz -o ${invwarp_out} -r ${TARGDIR}/mpr

# This is applying the non-brain extracted T1w to MNI warp (computed above) to 
# the brain extracted T1w, then binarizing to create a T1w to MNI brain mask
inname1=${TARGDIR}/${SESST}_mpr_brain 
outname1=${TARGDIR}/anat_mni_underlay_brain
outname2=${TARGDIR}/anat_mni_underlay_brain_mask

applywarp --ref=${TARGDIR}/anat_mni_underlay.nii.gz --in=${inname1} --warp=${TARGDIR}/mpr_to_mni_FNIRT.mat.nii.gz --rel --out=${outname1}

fslmaths ${outname1} -bin ${outname2}

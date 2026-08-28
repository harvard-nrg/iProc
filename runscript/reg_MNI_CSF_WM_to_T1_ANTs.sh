#!/bin/bash
set -xeou pipefail
TARGDIR=${1}
SESST=${2}
csf_out=${3}
wm_out=${4}
maskdir=${5}
MNI111_ATLAS=${6}


#Path to MNI masks
mkdir -m 750 -p ${TARGDIR}/mni_masks
wbmask=$maskdir/avg152T1_brain_MNI
wmmask=$maskdir/avg152T1_WM_MNI
csfmask=$maskdir/avg152T1_ventricles_MNI

#TODO: make relative
ln -sf ${wmmask}.nii.gz $TARGDIR/mni_masks/wm_mask.nii.gz
ln -sf ${csfmask}.nii.gz $TARGDIR/mni_masks/csf_mask.nii.gz

#Upsample masks to 1mm space
flirt -in $TARGDIR/mni_masks/csf_mask.nii.gz -applyxfm -init ${FSLDIR}/etc/flirtsch/ident.mat -out $TARGDIR/mni_masks/csf_mask_1mm.nii.gz -paddingsize 0.0 -interp trilinear -ref $MNI111_ATLAS
flirt -in $TARGDIR/mni_masks/wm_mask.nii.gz -applyxfm -init ${FSLDIR}/etc/flirtsch/ident.mat -out $TARGDIR/mni_masks/wm_mask_1mm.nii.gz -paddingsize 0.0 -interp trilinear -ref $MNI111_ATLAS

elif [ "${REG_STRATEGY}" == "ants" ]; then
#Project masks to T1
antsApplyTransforms --default-value 0 \
  --verbose 1 \
  --dimensionality 3 \
  --float 1 \
  --input $TARGDIR/mni_masks/csf_mask.nii.gz \
  --output $TARGDIR/mni_masks/csf_mask_mpr.nii.gz \
  --interpolation LanczosWindowedSinc \
  --reference-image ${TARGDIR}/${SESST}_mpr.nii.gz \
  --transform ${TARGDIR}/mpr_brain_to_MNI_3_InverseComposite.h5

antsApplyTransforms --default-value 0 \
  --verbose 1 \
  --dimensionality 3 \
  --float 1 \
  --input $TARGDIR/mni_masks/wm_mask.nii.gz \
  --output $TARGDIR/mni_masks/wm_mask_mpr.nii.gz \
  --interpolation LanczosWindowedSinc \
  --reference-image ${TARGDIR}/${SESST}_mpr.nii.gz \
  --transform ${TARGDIR}/mpr_brain_to_MNI_3_InverseComposite.h5

fslmaths ${TARGDIR}/${SESST}_mpr_brain.nii.gz -bin ${TARGDIR}/${SESST}_mpr_brain_mask.nii.gz

fi 

ln -sf ${TARGDIR}/${SESST}_mpr_reorient_brain_mask.nii.gz $TARGDIR/mni_masks/wb_mask_mpr_reorient.nii.gz
fslreorient2std $TARGDIR/mni_masks/csf_mask_mpr.nii.gz ${csf_out}
fslreorient2std $TARGDIR/mni_masks/wm_mask_mpr.nii.gz ${wm_out}


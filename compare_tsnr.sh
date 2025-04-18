module load ncf fsl/6.0.4-centos7_x64-ncf

SUB=7JK25
SES=240401_7JK25
TYPE=Cornell

RESTNAME=RESTCOR
NBACK1=008
NBACK2=077
REST1=060
REST2=091

BASE=/n/nrg_l3/Lab/users/jsegawa/iProc_MEPILOT/

DATA_DIR=${BASE}/${TYPE}/mri_data/${SUB}/NAT111/${SES}


BOLD_ORIG=${DATA_DIR}/${RESTNAME}_${NBACK1}/${SES}_bld${NBACK1}_reorient_skip_mc_unwarp_anat_resid_bpss.nii.gz
fslmaths $BOLD_ORIG -Tmean bold_mean.nii.gz
fslmaths bold.nii.gz -Tstd bold_std.nii.gz
fslmaths bold_mean.nii.gz -div bold_std.nii.gz TSNR_map.nii.gz
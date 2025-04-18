#!/bin/bash
set -xeou pipefail
#SESST=${1}
#TARGDIR=${2}
#MOVIMG=${3}
#VREG_REG=${4}
#VREG_MAT=${5}
#rmfiles=${6:-''}

#bbregister --bold --s $SESST --init-fsl --mov ${MOVIMG} --reg ${VREG_REG} --fslmat ${VREG_MAT}


#if [ -n "$rmfiles" ]; then
#    for f in $rmfiles;do
#        rm -rf "$f"
#    done
#fi

REG=/n/nrg_l3/Lab/users/jsegawa/iProc_MEPILOT/Cornell/mri_data/7JK25/cross_session_maps/templates/7JK25_allscans_meanBOLD_to_T1.dat
ANAT=/n/nrg_l3/Lab/users/jsegawa/iProc_MEPILOT/Cornell/mri_data/7JK25/NAT/240401_7JK25/ANAT_057/240401_7JK25_mpr057_reorient.nii.gz
BOLD=/n/nrg_l3/Lab/users/jsegawa/iProc_MEPILOT/Cornell/mri_data/7JK25/cross_session_maps/templates/7JK25midmean_midvols_on_midvoltarg.nii.gz
#BOLD=/n/nrg_l3/Lab/users/jsegawa/iProc_MEPILOT/Cornell/mri_data/7JK25/NAT/240401_7JK25/NBACKMECOR_008/240401_7JK25_bld008_reorient_skip_mc_midvol_unwarp.nii.gz
OUTANAT=/n/nrg_l3/Lab/users/jsegawa/iProc_MEPILOT/Cornell/mri_data/7JK25/NAT/240401_7JK25/ANAT_057/240401_7JK25_mpr057_reorient_BOLDspace.nii.gz

mri_vol2vol --targ ${ANAT} --mov ${BOLD} --o ${OUTANAT} --reg ${REG} --inv --nearest #with inv flag, mov is output template, targ is input

#!/bin/bash
set -xeou pipefail
TARGDIR=${1}
invwarp_out=${2}
ATLAS=${3}
ATLASB=${4}
ATLASBM=${5}
SESST=${6}
REG_STRATEGY=${7}

#TODO: should this be there?
fslswapdim ${TARGDIR}/mpr_reorient_brain.nii.gz x -z y ${TARGDIR}/mpr_brain.nii.gz


# Use FSL flirt/fnirt to move to MNI space
if [ "${REG_STRATEGY}" == "fnirt" ]; then
flirt -in ${TARGDIR}/mpr_brain -ref ${ATLASB} -out ${TARGDIR}/mpr_brain_mni -omat ${TARGDIR}/mpr_brain_to_mni.mat -bins 256 -cost corratio -searchrx -180 180 -searchry -180 180 -searchrz -180 180 -dof 12 -interp trilinear

fnirt --in=${TARGDIR}/mpr --iout=${TARGDIR}/anat_mni_underlay --ref=${ATLAS} --refmask=${ATLASBM} --aff=${TARGDIR}/mpr_brain_to_mni.mat --cout=${TARGDIR}/mpr_to_mni_FNIRT.mat

invwarp -w ${TARGDIR}/mpr_to_mni_FNIRT.mat.nii.gz -o ${invwarp_out} -r ${TARGDIR}/mpr

# This is applying the non-brain extracted T1w to MNI warp (computed above) to
# the brain extracted T1w, then binarizing to create a T1w to MNI brain mask
inname1=${TARGDIR}/${SESST}_mpr_brain
outname1=${TARGDIR}/anat_mni_underlay_brain
outname2=${TARGDIR}/anat_mni_underlay_brain_mask

applywarp --ref=${TARGDIR}/anat_mni_underlay.nii.gz --in=${inname1} --warp=${TARGDIR}/mpr_to_mni_FNIRT.mat.nii.gz --rel --out=${outname1}



# Use Ants to move to MNI space 
elif [ "${REG_STRATEGY}" == "ants" ]; then

# Switching to ants Registration - Optimized for STAR T1 to MNI
T1w1=${TARGDIR}/mpr_brain.nii.gz
MNI=${ATLASB}

#set +e
if [[ ! -e ${T1w1%.nii.gz}_to_MNI_1Q_Warped.nii.gz ]]; then
antsRegistrationSyNQuick.sh \
    -t s  \
    -p f \
    -d 3  \
    -o "${T1w1%.nii.gz}_to_MNI_1Q_" \
    -f ${MNI} \
    -m ${T1w1}  > ${T1w1%.nii.gz}_to_MNI_1Q_antsRegistrationSyNQuick_Ts.txt
set -e
fi

# Perform ants Registration twice - One for combined transform outputs and second for separate.
if [[ ! -e ${T1w1%.nii.gz}_to_MNI_3_Warped.nii.gz ]]; then
antsRegistration --verbose 1 \
        --dimensionality 3 \
        --float 1 \
        --collapse-output-transforms 1 \
        --output [ ${T1w1%.nii.gz}_to_MNI_3_,${T1w1%.nii.gz}_to_MNI_3_Warped.nii.gz,${T1w1%.nii.gz}_to_MNI_3_InverseWarped.nii.gz ] \
        --interpolation LanczosWindowedSinc \
        --use-histogram-matching 0 \
        --winsorize-image-intensities [ 0.005,0.995 ] \
        --initial-moving-transform [ ${MNI},${T1w1},1 ] \
        --transform Rigid[ 0.1 ] \
        --metric MI[ ${MNI}, ${T1w1},1,32,Regular,0.25 ] \
        --convergence [ 1000x500x250x0,1e-6,10 ] \
        --shrink-factors 8x4x2x1 \
        --smoothing-sigmas 3x2x1x0vox \
        --transform Affine[ 0.1 ] \
        --metric MI[ ${MNI}, ${T1w1},1,32,Regular,0.25 ] \
        --convergence [ 1000x500x250x0,1e-6,10 ] \
        --shrink-factors 8x4x2x1 \
        --smoothing-sigmas 3x2x1x0vox \
        --transform SyN[ 0.1,3,0 ] \
        --metric CC[ ${MNI}, ${T1w1},1,4,None,1 ] \
        --convergence [ 100x70x50x0,1e-6,10 ] \
        --shrink-factors 8x4x2x1 \
        --smoothing-sigmas 3x2x1x0vox \
        --write-composite-transform 1
fi

if [[ ! -e ${T1w1%.nii.gz}_to_MNI_2_Warped.nii.gz ]]; then
antsRegistration --verbose 1 \
        --dimensionality 3 \
        --float 1 \
        --collapse-output-transforms 0 \
        --output [ ${T1w1%.nii.gz}_to_MNI_2_,${T1w1%.nii.gz}_to_MNI_2_Warped.nii.gz,${T1w1%.nii.gz}_to_MNI_2_InverseWarped.nii.gz ] \
        --interpolation LanczosWindowedSinc \
        --use-histogram-matching 0 \
        --winsorize-image-intensities [ 0.005,0.995 ] \
        --initial-moving-transform [ ${MNI},${T1w1},1 ] \
        --transform Rigid[ 0.1 ] \
        --metric MI[ ${MNI}, ${T1w1},1,32,Regular,0.25 ] \
        --convergence [ 1000x500x250x0,1e-6,10 ] \ 
        --shrink-factors 8x4x2x1 \
        --smoothing-sigmas 3x2x1x0vox \
        --transform Affine[ 0.1 ] \
        --metric MI[ ${MNI}, ${T1w1},1,32,Regular,0.25 ] \
        --convergence [ 1000x500x250x0,1e-6,10 ] \
        --shrink-factors 8x4x2x1 \
        --smoothing-sigmas 3x2x1x0vox \
        --transform SyN[ 0.1,3,0 ] \
        --metric CC[ ${MNI}, ${T1w1},1,4,None,1 ] \
        --convergence [ 100x70x50x0,1e-6,10 ] \
        --shrink-factors 8x4x2x1 \
        --smoothing-sigmas 3x2x1x0vox \
        --write-composite-transform 0


        
# directory moved to within iProc
c3dDIR=/ncf/mclaughlin/stressdevlab/STAR/2_scripts/3_Functional/1_iProc_STAR/iProc/runscript/c3d/c3d-1.1.0-Linux-x86_64/bin
#/ncf/mclaughlin/stressdevlab/STAR/2_scripts/3_Functional/c3d_test/c3d-1.1.0-Linux-x86_64/bin
    
# Conversion of ANTS-created affine registration matrix to FSL-compatible affine registration matrix
# Mark Jenkinson: https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=fsl;c21935f9.1901
# Add c3d toolbox to iproc's toolbox?
        
${c3dDIR}/c3d_affine_tool \
        -ref ${MNI} \
        -src ${T1w1} \
        -itk ${T1w1%.nii.gz}_to_MNI_1Q_0GenericAffine.mat \
        -ras2fsl \
        -o ${T1w1%.nii.gz}_to_MNI_OUT_flirt.mat
        
wb_contain -v 1.3.2 wb_command -convert-warpfield \
  -from-itk ${T1w1%.nii.gz}_to_MNI_2_3Warp.nii.gz \
  -to-fnirt ${T1w1%.nii.gz}_to_MNI_warp_OUT_fnirt.mat.nii.gz \
  ${MNI}
        
convertwarp --ref=${MNI} \
  --premat=${T1w1%.nii.gz}_to_MNI_OUT_flirt.mat \ 
  --warp1=${T1w1%.nii.gz}_to_MNI_warp_OUT_fnirt.mat.nii.gz \
  --out=${T1w1%.nii.gz}_to_MNI_OUT2FSL_warp.nii.gz
        
#invwarp -w ${T1w1%.nii.gz}_to_MNI_OUT2FSL_warp \  
#  -o ${T1w1%.nii.gz}_to_MNI_OUT2FSL_invwarp \ 
#  -r ${T1w1}
        
applywarp --in=${T1w1} \
  --ref=${MNI} \
  --warp=${T1w1%.nii.gz}_to_MNI_OUT2FSL_warp \
  --abs \
  --out=${TARGDIR}/OUT_T1_to_MNI_abs.nii.gz

fi
        
# Making names comparable:
if [[ ! -e ${TARGDIR}/anat_mni_underlay_brain.nii.gz ]]; then
#ln -s ${T1w1%.nii.gz}_to_MNI_Warped.nii.gz ${TARGDIR}/anat_mni_underlay.nii.gz
ln -s ${T1w1%.nii.gz}_to_MNI_3_Warped.nii.gz ${TARGDIR}/anat_mni_underlay_brain.nii.gz
ln -s ${TARGDIR}/anat_mni_underlay_brain.nii.gz ${TARGDIR}/anat_mni_underlay.nii.gz
fi
  
outname1=${TARGDIR}/anat_mni_underlay_brain # T1 in MNI space
outname2=${TARGDIR}/anat_mni_underlay_brain_mask # T1 in MNI space
  
fi 

fslmaths ${outname1} -bin ${outname2}

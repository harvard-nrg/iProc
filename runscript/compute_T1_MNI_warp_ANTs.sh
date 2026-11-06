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
fi
# the conversion below runs outside the guard, so a rerun after a failed conversion doesn't skip it

# Conversion of ANTS-created affine registration matrix to FSL-compatible affine registration matrix
# Mark Jenkinson: https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=fsl;c21935f9.1901
# the c3d module (1.0.0) can't read ANTs' single-precision affine, so convert it to double first
ConvertTransformFile 3 ${T1w1%.nii.gz}_to_MNI_1Q_0GenericAffine.mat ${T1w1%.nii.gz}_to_MNI_1Q_0GenericAffine_double.mat --convertToAffineType

c3d_affine_tool \
        -ref ${MNI} \
        -src ${T1w1} \
        -itk ${T1w1%.nii.gz}_to_MNI_1Q_0GenericAffine_double.mat \
        -ras2fsl \
        -o ${T1w1%.nii.gz}_to_MNI_OUT_flirt.mat

# the module's wb_command needs graphics libraries the kilmer container lacks; Workbench's own launcher and bundled software-OpenGL libraries don't
WB_DIR=$(dirname $(dirname $(command -v wb_command)))
LD_LIBRARY_PATH=${WB_DIR}/libs_rh_linux64_software_opengl${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}} ${WB_DIR}/bin_rh_linux64/wb_command -convert-warpfield \
  -from-itk ${T1w1%.nii.gz}_to_MNI_2_3Warp.nii.gz \
  -to-fnirt ${T1w1%.nii.gz}_to_MNI_warp_OUT_fnirt.mat.nii.gz \
  ${MNI}

# relative convention, like FNIRT's warps: the BOLD-to-MNI step reads this warp without a convention flag and treats it as relative
convertwarp --ref=${MNI} \
  --premat=${T1w1%.nii.gz}_to_MNI_OUT_flirt.mat \
  --warp1=${T1w1%.nii.gz}_to_MNI_warp_OUT_fnirt.mat.nii.gz \
  --out=${T1w1%.nii.gz}_to_MNI_OUT2FSL_warp.nii.gz \
  --relout

# inverse warp (MNI to T1), iProc's output for this step; built from ANTs' own inverse transforms because FSL's invwarp doesn't invert this warp correctly
antsApplyTransforms -d 3 -r ${T1w1} -o [${T1w1%.nii.gz}_to_MNI_inverse_itk.nii.gz,1] \
  -t [${T1w1%.nii.gz}_to_MNI_1Q_0GenericAffine.mat,1] -t ${T1w1%.nii.gz}_to_MNI_2_3InverseWarp.nii.gz
LD_LIBRARY_PATH=${WB_DIR}/libs_rh_linux64_software_opengl${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}} ${WB_DIR}/bin_rh_linux64/wb_command -convert-warpfield \
  -from-itk ${T1w1%.nii.gz}_to_MNI_inverse_itk.nii.gz \
  -to-fnirt ${T1w1%.nii.gz}_to_MNI_inverse_fnirt.nii.gz \
  ${MNI}
convertwarp --ref=${T1w1} \
  --warp1=${T1w1%.nii.gz}_to_MNI_inverse_fnirt.nii.gz \
  --out=${invwarp_out} \
  --relout

applywarp --in=${T1w1} \
  --ref=${MNI} \
  --warp=${T1w1%.nii.gz}_to_MNI_OUT2FSL_warp \
  --rel \
  --out=${TARGDIR}/OUT_T1_to_MNI.nii.gz

# the BOLD-to-MNI step reads the forward warp under this name
ln -sf $(basename ${T1w1%.nii.gz})_to_MNI_OUT2FSL_warp.nii.gz ${TARGDIR}/mpr_to_mni_ANTs.mat.nii.gz
        
# Making names comparable:
if [[ ! -e ${TARGDIR}/anat_mni_underlay_brain.nii.gz ]]; then
#ln -s ${T1w1%.nii.gz}_to_MNI_Warped.nii.gz ${TARGDIR}/anat_mni_underlay.nii.gz
ln -s ${T1w1%.nii.gz}_to_MNI_3_Warped.nii.gz ${TARGDIR}/anat_mni_underlay_brain.nii.gz
ln -s ${TARGDIR}/anat_mni_underlay_brain.nii.gz ${TARGDIR}/anat_mni_underlay.nii.gz
fi
  
outname1=${TARGDIR}/anat_mni_underlay_brain # T1 in MNI space
outname2=${TARGDIR}/anat_mni_underlay_brain_mask # T1 in MNI space

fslmaths ${outname1} -bin ${outname2}

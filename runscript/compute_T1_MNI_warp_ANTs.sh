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

# One full ants registration (rigid, affine, SyN), saved as forward and inverse composite transforms
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
# the conversion below runs outside the guard, so a rerun after a failed conversion doesn't skip it

# the module's wb_command needs graphics libraries the kilmer container lacks; Workbench's own launcher and bundled software-OpenGL libraries don't
WB_DIR=$(dirname $(dirname $(command -v wb_command)))
wb_command_bundled() {
  LD_LIBRARY_PATH=${WB_DIR}/libs_rh_linux64_software_opengl${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}} ${WB_DIR}/bin_rh_linux64/wb_command "$@"
}

# forward warp (T1 to MNI): the whole registration written as one displacement field on the MNI grid, then converted to FSL.
# Workbench's source volume is the image the warp is applied to, the T1.
# Relative convention, like FNIRT's warps: the BOLD-to-MNI step reads this warp without a convention flag and treats it as relative.
antsApplyTransforms -d 3 -r ${MNI} -o [${T1w1%.nii.gz}_to_MNI_itk.nii.gz,1] -t ${T1w1%.nii.gz}_to_MNI_3_Composite.h5
wb_command_bundled -convert-warpfield -from-itk ${T1w1%.nii.gz}_to_MNI_itk.nii.gz -to-fnirt ${T1w1%.nii.gz}_to_MNI_fnirt.nii.gz ${T1w1}
convertwarp --ref=${MNI} --warp1=${T1w1%.nii.gz}_to_MNI_fnirt.nii.gz --out=${T1w1%.nii.gz}_to_MNI_OUT2FSL_warp.nii.gz --relout

# inverse warp (MNI to T1), iProc's declared output for this step: the inverse composite written the same way, with the MNI template as source
antsApplyTransforms -d 3 -r ${T1w1} -o [${T1w1%.nii.gz}_to_MNI_inverse_itk.nii.gz,1] -t ${T1w1%.nii.gz}_to_MNI_3_InverseComposite.h5
wb_command_bundled -convert-warpfield -from-itk ${T1w1%.nii.gz}_to_MNI_inverse_itk.nii.gz -to-fnirt ${T1w1%.nii.gz}_to_MNI_inverse_fnirt.nii.gz ${MNI}
convertwarp --ref=${T1w1} --warp1=${T1w1%.nii.gz}_to_MNI_inverse_fnirt.nii.gz --out=${invwarp_out} --relout

applywarp --in=${T1w1} \
  --ref=${MNI} \
  --warp=${T1w1%.nii.gz}_to_MNI_OUT2FSL_warp \
  --rel \
  --out=${TARGDIR}/OUT_T1_to_MNI.nii.gz

# the BOLD-to-MNI step reads the forward warp under this name
ln -sf $(basename ${T1w1%.nii.gz})_to_MNI_OUT2FSL_warp.nii.gz ${TARGDIR}/mpr_to_mni_ANTs.mat.nii.gz

# Making names comparable; relative links, so they also work outside the container that made them
ln -sf $(basename ${T1w1%.nii.gz})_to_MNI_3_Warped.nii.gz ${TARGDIR}/anat_mni_underlay_brain.nii.gz
ln -sf anat_mni_underlay_brain.nii.gz ${TARGDIR}/anat_mni_underlay.nii.gz

outname1=${TARGDIR}/anat_mni_underlay_brain # T1 in MNI space
outname2=${TARGDIR}/anat_mni_underlay_brain_mask # T1 in MNI space

fslmaths ${outname1} -bin ${outname2}

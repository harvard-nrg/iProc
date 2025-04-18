#!/bin/bash
# load modules and set environmental variables for development purposes,
# when you are not loading iProc via a module

__dir__=$(readlink -f $(dirname "${BASH_SOURCE[0]}"))

module load \
  ncf/1.0.0-fasrc01 \
  parallel/20180522-rocky8_x64-ncf \
  miniconda3/4.5.12-ncf \
  mricron/2012_12-ncf \
  niftidiff/1.0-ncf \
  afni/2016_09_04-ncf \
  matlab/7.4-ncf \
  fsl/5.0.10-centos7_x64-ncf \
  mricrogl/2019_09_04-ncf \
  yaxil/0.2.2-nodcm2niix \
  freesurfer/6.0.0-ncf \
  imagemagick/6.7.8-10-rocky8_x64-ncf \
  ants/2.4.4-rocky8_x64-ncf \
  connectome_workbench/1.3.2-centos6_x64-ncf \
  dcm2niix/1.0.20230411-rocky8_x64-ncf


#fsl/5.0.4-ncf 

#export _IPROC_CODEDIR=$(pwd)
echo "${__dir__}"
export _IPROC_CODEDIR="${__dir__}"
echo $_IPROC_CODEDIR

export PYTHONPATH="$PYTHONPATH:$(pwd)"
echo $PYTHONPATH
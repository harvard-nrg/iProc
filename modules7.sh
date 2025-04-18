#!/bin/bash
# load modules and set environmental variables for development purposes, 
#when you are not loading iproc via the module
module load parallel/20180522-fasrc01 ncf/1.0.0-fasrc01 miniconda3/4.5.12-ncf afni/2016_09_04-ncf fsl/5.0.4-ncf freesurfer/6.0.0-ncf mricrogl/2019_09_04-ncf matlab/7.4-ncf yaxil/0.2.2-nodcm2niix mricron/2012_12-ncf imagemagick/6.7.8.10-ncf
module unload miniconda2
export _IPROC_CODEDIR=$(pwd)

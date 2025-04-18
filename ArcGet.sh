module load ncf/1.0.0-fasrc01
module load venv/yaxil/0.7.2-ncf
sub=$1
ses=$2
#outdir=/ncf/sba05/PROFETT_pilot/${subj}
#outdir=/n/fasse/users/abillot/Desktop/QC/${sub}
outdir=/n/nrg_l3/Lab/users/jsegawa/iProc/data
mkdir -p $outdir
ArcGet.py -a cbscentral02 -l ${ses} --readme > ${outdir}/${sub}_CBS_${sesh}.csv

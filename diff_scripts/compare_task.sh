#!/bin/bash
# generates report comparing all nii.gz files in one task directory to images with the same name in secondDir

firstDir=$1
secondDir=$2
outFile=diffs.$(date +%s)
OUTSPACE='NAT111 MNI111 FS6'
sessions='170714_HTP02023_trunc 170716_HTP02025_trunc'
scanType='CONF*'
echo $outFile

for space in $OUTSPACE ; do
    space_dir=$firstDir/$space
    for sess in $sessions ; do
        sess_dir=$space_dir/$sess
        for scan in $sess_dir/$scanType ; do
            echo $scan >> $outFile
            for image in $scan/*nii.gz ; do
                imageName=$(basename $image)
                scanName=$(basename $scan)
                sessName=$(basename $sess)
                secondImage=$secondDir/$space/$sessName/$scanName/$imageName
                niftidiff $image $secondImage || echo "niftidiff $image $secondImage" >> $outFile
            done
        done
    done
done
echo OUTFILE: $outFile

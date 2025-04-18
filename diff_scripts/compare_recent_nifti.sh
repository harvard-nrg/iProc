#!/bin/bash
## 
# finds all the niftis newer than N minutes in $1, and tries to compare to any identically-named niftis in $2. 
#useful for tracking down where differences arose.

function niftidiff_in_order {
local baseDir=$1
local comparisonDir=$2
pushd $baseDir
for x in $(find . -type f -mmin -600 -name *.nii.gz -exec stat --format '%Y :%y %n' "{}" \; | sort -n | cut -d: -f2-  | awk '{print $4}')
do 
  # copy and paste job, not sure if it'll work with single brackets
  if [[ $x == *"/QC/"* ]]; then
      # ineligible because tmp directories are unique
      continue
  fi
  # OK, let's run niftidiff
  local f=${x#.}
  niftidiff $x $comparisonDir/$f || echo $x >> diff.txt
  niftidiff $x $comparisonDir/$f | grep nan &&  echo $x >> nanList.txt
done
popd
}

niftidiff_in_order $1 $2

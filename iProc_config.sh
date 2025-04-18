#!/bin/bash
## print sample configs to the command line

# get parent path of this script in particular
parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )


pushd "$parent_path"/example_user_files >> /dev/null
for file in * ; 
do
    echo
    echo $file
    echo "================================================================================"
    cat $file
done 
#move back to original dir silently
popd >> /dev/null

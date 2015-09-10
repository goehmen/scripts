#!/bin/bash -x
#
# update-cli contains code to d/l unstable versions of the cli, which
# are indicated by a build number or SHA. HOWEVER, when downloading a
# stable release, update-cli shouldn't append the build.

testsDir=$(cd $(dirname $0); pwd)
bin=$(basename $testsDir)
parentDir=${testsDir%/*}
binDir=${parentDir%/*}

source $parentDir/utils.sh

prep_tmpdir
echo "tmpdir is: $tmpdir"

${binDir}/$bin -x -c ltc -p $tmpdir -r stable
${binDir}/$bin -x -c cf -p $tmpdir -r stable

failCount=0
# There should be one link pointing to a file with the cli-ver format
ltcbin=$(readlink $tmpdir/ltc) 
echo $ltcbin | egrep -q -e 'ltc-v[\.0-9]*$'
if [ 0 -ne $? ]; then
    echo "FAILED: ltc link ($ltcbin) does not point to a filename that uses only the version number."
    failCount=$((failCount + 1))
fi

# There should be one link pointing to a file with the cli-ver-SHA format
cfbin=$(readlink $tmpdir/cf) 
echo $cfbin | egrep -q -e 'cf-([.[:digit:]]+)$'

if [ 0 -ne $? ]; then
    echo "FAILED: cf link ($cfbin) does not point to a filename that uses only the version number."
    failCount=$((failCount + 1))
fi
if [ 0 -eq $failCount ]; then
    rm -r $tmpdir
    exit 0
else
    echo "FAILED with $failCount errors"
    exit $failCount
fi

    

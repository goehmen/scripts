#!/bin/bash
#
# Default test - does it do the right thing with an empty directory?

testsDir=$(cd $(dirname $0); pwd)
bin=$(basename $testsDir)
parentDir=${testsDir%/*}
binDir=${parentDir%/*}

source $parentDir/utils.sh

prep_tmpdir
echo "tmpdir is: $tmpdir"

${binDir}/$bin -x -p $tmpdir

failCount=0
# There should be one link, one binary.
c=0
for i in ${tmpdir}/*; do c=$((c + 1)); done

if [ $c -ne 2 ]; then
    echo "FAILED: incorrect number of files in tmp bindir"
    failCount=$((failCount + 1))
fi

if [ ! -L ${tmpdir}/cf ]; then
    echo "FAILED: no cf link."
    failCount=$((failCount + 1))
fi

if [ ! -f ${tmpdir}/cf-* ]; then
    echo "FAILED: no binary file."
    failCount=$((failCount + 1))
fi

if [ 0 -eq $failCount ]; then
    rm -r $tmpdir
    exit 0
else
    echo "FAILED with $failCount errors"
    exit $failCount
fi

    

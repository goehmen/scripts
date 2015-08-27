#!/bin/sh

testsDir=$(cd $(dirname $0); pwd)
bin=$(basename $testsDir)
parentDir=${testsDir%/*}
binDir=${parentDir%/*}

source $parentDir/utils.sh

prep_tmpdir
echo "tmpdir is $tmpdir"

${binDir}/$bin -xp $tmpdir -u file://not-there

exit_code=$?
echo "Exit code: $exit_code"

# We'll never need to inspect the tmpdir
rm -r $tmpdir

if [ 0 -eq $exit_code ]; then
    echo "FAILED: Expected non-zero exit code."
    exit 1
else
    exit 0;
fi

#!/bin/bash
#
# Does it do the right thing if a binary already exists in the target dir?

testsDir=$(cd $(dirname $0); pwd)
bin=$(basename $testsDir)
parentDir=${testsDir%/*}
binDir=${parentDir%/*}

source $parentDir/utils.sh

prep_tmpdir
echo "tmpdir is: $tmpdir"

cat > ${tmpdir}/cf <<-EOF
	#!/bin/sh
	echo "cf fake version 0.0.1-abcde"
EOF

failCount=0

# First test if it fails when the existing binary isn't executable
${binDir}/$bin -x -p $tmpdir

if [ 3 -ne $? ]; then
    echo "FAILED: Should have exit 3 at non-executable existing bin."
    failCount=$((failCount + 1))
fi

chmod +x ${tmpdir}/cf

${binDir}/$bin -x -p $tmpdir

# There should be two links, two binaries
c=0
for i in ${tmpdir}/*; do c=$((c + 1)); done

if [ $c -ne 4 ]; then
    echo "FAILED: incorrect number of files in tmp bindir"
    failCount=$((failCount + 1))
fi

if [ ! -L ${tmpdir}/cf.old ]; then
    echo "FAILED: no cf link."
    failCount=$((failCount + 1))
fi

if [ ! -f ${tmpdir}/cf-0.0.1* ]; then
    echo "FAILED: no old binary file."
    failCount=$((failCount + 1))
fi

if [ 0 -eq $failCount ]; then
    rm -r $tmpdir
    exit 0
else
    echo "FAILED with $failCount errors"
    exit $failCount
fi

    

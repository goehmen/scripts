#!/bin/sh

set -e

# API_TOKEN=${API_TOKEN:?[ERROR]: API_TOKEN environment variable must be set.}
PRIVATE=0

usage="\
$0 -r version

    Download a cf-mysql-release RC from S3.

Options:
    -h                This help
    -p                Specify that this is PCF, not an OSS RC
    -r version        Specify the version to be downloaded, e.g. 24.21.0
"

args=`getopt phr: $*`; errcode=$?; set -- $args
if [ 0 -ne $errcode ]; then echo ; echo "$usage" ; exit $errcode ; fi

for i ; do
    case $i in
        -h)
            echo "$usage"
            exit 0
            ;;
        -p)
            PRIVATE=1
            shift ; 
            ;;
        -r)
            VERSION=$2
            shift ; shift ;;
    esac
done

if [ "--" == $1 ]; then shift; fi

if [ 1 == $PRIVATE ]; then
    s3File="s3://pcf-mysql-releases/final/cf-mysql-${VERSION}.tgz"
else
    s3File="s3://cf-mysql-releases/final/cf-mysql-${VERSION}.tgz"
fi    

aws s3 cp ${s3File} .
errcode=$?

if [ 0 -ne $errcode ]; then
    echo "[ERROR] Failed to download RC file."
    exit $errcode
fi

exit 0


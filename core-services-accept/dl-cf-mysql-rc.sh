#!/bin/sh

set -e

# API_TOKEN=${API_TOKEN:?[ERROR]: API_TOKEN environment variable must be set.}
PRIVATE=0
VERSION=""

usage="\
$0 -r version

    Download a cf-mysql-release RC from S3.

Options:
    -h                This help
    -P                Specify that this is PCF, not an OSS RC
    -p                Specify a product name (defaults to cf-mysql)
    -r version        Specify the version to be downloaded, e.g. 24.21.0
    -d                Debug mode
"

args=`getopt dPphr: $*`; errcode=$?; set -- $args
if [ 0 -ne $errcode ]; then echo ; echo "$usage" ; exit $errcode ; fi

for i ; do
    case $i in
        -h)
            echo "$usage"
            exit 0
            ;;
        -P)
            PRIVATE=1
            shift ; 
            ;;
        -p)
            echo "[ERROR] Not yet implemented"
            exit 1
            ;;
        -r)
            VERSION=$2
            shift ; shift ;;
        -d)
            set -x
            shift ;
            ;;
    esac
done

if [ "--" == $1 ]; then shift; fi

if [ 1 == $PRIVATE ]; then
    s3Path="s3://pcf-mysql-releases/final/"
else
    s3Path="s3://cf-mysql-releases/final/"
fi    

if [ "X" == $VERSION"X" ]; then
    rcFile=$(aws s3 ls ${s3Path} | gsort -V -rk4 | awk 'NR == 1 {print $4}')
else
    rcFile="cf-mysql-${VERSION}.tgz"
fi


aws s3 cp "${s3Path}${rcFile}" .
errcode=$?

if [ 0 -ne $errcode ]; then
    echo "[ERROR] Failed to download RC file."
    exit $errcode
fi

exit 0


#!/bin/sh

set -e

# API_TOKEN=${API_TOKEN:?[ERROR]: API_TOKEN environment variable must be set.}
FINAL=0
PROFILE="default"
VERSION=""

usage="\
$0 -r version

    Download a cf-mysql-release RC from S3.

Options:
    -h                This help
    -f                Download the latest final release, not a release-candidate.
    -p                Specify a product name (defaults to cf-mysql)
    -r version        Specify the version to be downloaded, e.g. 24.21.0
    -i profile        AWS profile to specify when running s3 client. (optional)
    -d                Debug mode
"

args=`getopt dfphi:r: $*`; errcode=$?; set -- $args
if [ 0 -ne $errcode ]; then echo ; echo "$usage" ; exit $errcode ; fi

for i ; do
    case $i in
        -h)
            echo "$usage"
            exit 0
            ;;
        -f)
            FINAL=1
            shift ; 
            ;;
        -p)
            echo "[ERROR] Not yet implemented"
            exit 1
            ;;
        -r)
            VERSION=$2
            shift ; shift ;;
        -i)
            PROFILE=$2
            shift ; shift ;;
        -d)
            set -x
            shift ;
            ;;
    esac
done

if [ "--" == $1 ]; then shift; fi

if [ 1 == $FINAL ]; then
    s3Path="s3://cf-mysql-releases/final/"
else
    s3Path="s3://cf-mysql-releases/release-candidate/"
fi    

if [ "X" == $VERSION"X" ]; then
    rcFile=$(aws --profile=$PROFILE s3 ls ${s3Path} | gsort -V -rk4 | awk 'NR == 1 {print $4}')
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


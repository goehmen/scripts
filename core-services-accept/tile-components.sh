#!/bin/sh

set -e

WORKDIR="/var/tmp/t"
SUBDIR=$(date +"%Y-%m-%d-%H:%M:%S")
PROFILE="default"
PRODUCT="XX"
VERSION="XX"

usage="\
$0 -p product-name -r version [-i aws profile] [-t tmpdir] component

    Download the most recent version of a tile, validate contents within it.

Options:
    -h                This help
    -p product        Specify the name of the product, e.g. p-mysql
    -r version        Specify the version to be downloaded, e.g. 1.9.4
    -t tmpdir         Specify a working directory to use (optional. default /var/tmp/t)
    -i profile        AWS profile to specify when running s3 client (optional.)
    -v                debug mode
    component         Which version to validate, e.g. cf-mysql, stemcell, ...
"

args=`getopt vhxp:r:t:i: $*`; errcode=$?; set -- $args
if [ 0 -ne $errcode ]; then echo ; echo "$usage" ; exit $errcode ; fi

for i ; do
    case $i in
        -v)
	    set -x ; shift ;
            ;;
        -h)
            echo "$usage" ; exit 0
            ;;
        -p)
            PRODUCT=$2
            product_file="*.yml"
            shift ; shift ;;
        -r)
            VERSION=$2
            shift ; shift ;;
        -i)
            PROFILE=$2
            shift ; shift ;;
        -t)
            WORKDIR=$2
            shift ; shift ;;
        -x)
            echo "Debug mode."
            set -x ; shift ;;
    esac
done

if [ "XX" = "${PRODUCT}" -o "XX" = "${VERSION}" ]; then
    echo "[ERROR] Please specify product and version." ; echo
    echo "$usage"
    exit -1
fi

if [ "--" == $1 ]; then shift; fi

if [ ! -d ${WORKDIR} ]; then
    mkdir ${WORKDIR}
    if [ 0 -ne $? ]; then
        echo "[ERROR] Unable to create tmpdir, ${WORKDIR}."
        exit 2
    fi
fi

mkdir -p ${WORKDIR}/${SUBDIR} ; cd ${WORKDIR}/${SUBDIR} ;

case ${VERSION} in
    2.3*)
	s3Path="s3://dedicated-mysql-tile-blobs/p.mysql-2.3/tested-tiles/"
	;;
    2.2*)
	s3Path="s3://dedicated-mysql-tile-blobs/p.mysql-2.2/tested-tiles/"
	;;
    2.1*)
	s3Path="s3://dedicated-mysql-tile-blobs/p.mysql-2.1/tested-tiles/"
	;;
    2.0*)
	s3Path="s3://dedicated-mysql-tile-blobs/p.mysql-2.0/tested-tiles/"
        ;;
    1.10*)
        s3Path="s3://pcf-core-services-artifacts/p-mysql/master/tested/"
        ;;
    1.9*)
        s3Path="s3://pcf-core-services-artifacts/p-mysql/releases/1.9/tested/"
        ;;
    1.8*)
        s3Path="s3://pcf-core-services-artifacts/p-mysql/releases/1.8/tested/"
        ;;
    1.7*)
        s3Path="s3://pcf-core-services-artifacts/p-mysql/releases/1.7/tested/"
        ;;
esac

# If it hasn't already been downloaded, get the most recent RC in the correct AWS bucket
s3File=$(aws --profile=$PROFILE s3 ls $s3Path | grep $VERSION | sort -r | awk 'NR == 1 {print $4}')
if [ ! -f ${WORKDIR}/${s3File} ]; then 
    aws --profile=$PROFILE s3 cp ${s3Path}${s3File} ${WORKDIR}
fi
unzip -q ${WORKDIR}/${s3File}

case $1 in
    stemcell)
        awk '/product_version:/ {print} /stemcell/,/version/ {print}' metadata/${product_file}
        ;;
    *)
        awk "/name: $1/,/version: / {print} /product_version: / {print}" metadata/${product_file}
        ;;
esac

errcode=$?

if [ 0 -ne $errcode ]; then
    echo "[ERROR] Failed to produce output. Look in ${WORKDIR}/${SUBDIR} to debug."
    exit $errcode
fi

cd ${WORKDIR}
rm -r ${SUBDIR}

exit 0


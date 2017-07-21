#!/bin/sh

set -e

WORKDIR="/var/tmp/t"
SUBDIR=$(date +"%Y-%m-%d-%H:%M:%S")

usage="\
$0 -p product-name -r version [-t tmpdir] component

    Download a tile, validate certain contents within it.

Options:
    -h                This help
    -p product        Specify the name of the product, e.g. p-mysql
    -r version        Specify the version to be downloaded, e.g. 1.9.4
    -t tmpdir         Specify a working directory to use
    component         Which version to validate, e.g. cf-mysql, stemcell, ...
"

args=`getopt hp:r:t: $*`; errcode=$?; set -- $args
if [ 0 -ne $errcode ]; then echo ; echo "$usage" ; exit $errcode ; fi

for i ; do
    case $i in
        -h)
            echo "$usage" ; exit 0
            ;;
        -p)
            PRODUCT=$2
            product_file=$(echo $PRODUCT | tr '-' '_')
            shift ; shift ;;
        -r)
            VERSION=$2
            shift ; shift ;;
        -t)
            WORKDIR=$2
            shift ; shift ;;
    esac
done

if [ "--" == $1 ]; then shift; fi

API_TOKEN=${API_TOKEN:?[ERROR]: API_TOKEN environment variable must be set.}

if [ ! -d ${WORKDIR} ]; then
    mkdir ${WORKDIR}
    if [ 0 -ne $? ]; then
        echo "[ERROR] Unable to create tmpdir, ${WORKDIR}."
        exit 2
    fi
fi

mkdir -p ${WORKDIR}/${SUBDIR} ; cd ${WORKDIR}/${SUBDIR} ;

case ${VERSION} in
    1.9*)
        s3Path="s3://pcf-core-services-artifacts/p-mysql/master/tested/"
        ;;
    1.8*)
        s3Path="s3://pcf-core-services-artifacts/p-mysql/releases/1.8/tested/"
        ;;
    1.7*)
        s3Path="s3://pcf-core-services-artifacts/p-mysql/releases/1.7/tested/"
        ;;
esac

s3File=$(aws s3 ls $s3Path| sort -r | awk 'NR == 1 {print $4}')
aws s3 cp ${s3Path}${s3File} .
unzip -q $s3File

case $1 in
    stemcell)
        awk '/product_version:/ {print} /stemcell/,/version/ {print}' metadata/${product_file}.yml
        ;;
    cf-mysql)
        awk '/file: cf-mysql/,/version: / {print} /product_version: / {print}' metadata/${product_file}.yml
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


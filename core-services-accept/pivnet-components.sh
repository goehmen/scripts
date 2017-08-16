#!/bin/sh

set -e

WORKDIR="/var/tmp/t"
SUBDIR=$(date +"%Y-%m-%d-%H:%M:%S")
PRODUCT="XX"
VERSION="XX"

usage="\
$0 -p product-name -r version [-t tmpdir]

    Download a tile, validate certain contents within it.

Options:
    -h                This help
    -p product        Specify the name of the product, e.g. p-mysql
    -r version        Specify the version to be downloaded, e.g. 1.9.4
    -t tmpdir         Specify a working directory to use
    component         Which version to validate, e.g. cf-mysql, stemcell, ...
"

args=`getopt hxp:r:t: $*`; errcode=$?; set -- $args
if [ 0 -ne $errcode ]; then echo ; echo "$usage" ; exit $errcode ; fi

for i ; do
    case $i in
        -h)
            echo "$usage" ; exit 0
            ;;
        -p)
            PRODUCT=$2
            shift ; shift ;;
        -r)
            VERSION=$2
            shift ; shift ;;
        -t)
            WORKDIR=$2
            shift ; shift ;;
        -x)
            echo "Debug mode."
            set -x ; shift ;;
    esac
done

if [ "XX" = "${PRODDUCT}" -o "XX" = "${VERSION}" ]; then
    echo "[ERROR] Please specify product and version." ; echo
    echo "$usage"
    exit -1
fi

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

product_file=$(echo ${PRODUCT} | tr '-' '_').yml
file="${PRODUCT}-${VERSION}.pivotal"
jq_string=".[] | select (.name == \"$file\") | .id"

if [ ! -f ${WORKDIR}/${file} ]; then    
    pivnet login --api-token=${API_TOKEN}
    if [ 0 -ne $? ]; then
        echo "PivNet login failed. Check API_TOKEN and try again."
        exit 1
    fi
    product_file_id=$(pivnet product-files -p ${PRODUCT} -r ${VERSION} --format json | jq '.[] | select (.name == "'$file'") | .id')
    pivnet download-product-files -p ${PRODUCT} -r ${VERSION} -i ${product_file_id} --download-dir=.. --accept-eula
fi

unzip -q ../${file}

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

exit $?

#!/bin/sh

set -e

TMPDIR="/var/tmp/t"
API_TOKEN=${API_TOKEN:?[ERROR]: API_TOKEN environment variable must be set.}

usage="\
$0 -p product-name -r version [-t tmpdir]

    Download a tile, validate certain contents within it.

Options:
    -h                This help
    -p product        Specify the name of the product, e.g. p-mysql
    -r version        Specify the version to be downloaded, e.g. 1.9.4
    -t tmpdir         Specify a working directory to use
"

args=`getopt p:r:t: $*`; errcode=$?; set -- $args
if [ 0 -ne $errcode ]; then echo ; echo "$usage" ; exit $errcode ; fi

for i ; do
    case $i in
        -p)
            PRODUCT=$2
            shift ; shift ;;
        -r)
            VERSION=$2
            shift ; shift ;;
        -t)
            TMPDIR=$2
            shift ; shift ;;
    esac
done

if [ "--" == $1 ]; then shift; fi
    
if [ ! -d ${TMPDIR} ]; then
    mkdir ${TMPDIR}
    if [ 0 -ne $? ]; then
        echo "[ERROR] Unable to create tmpdir, ${TMPDIR}."
        exit 2
    fi
fi

cd ${TMPDIR}

pivnet login --api-token=${API_TOKEN}

if [ 0 -ne $? ]; then
   echo "PivNet login failed. Check API_TOKEN and try again."
   exit 1
fi

product_file=$(echo ${PRODUCT} | tr '-' '_')
file="${PRODUCT}-${VERSION}.pivotal"
jq_string=".[] | select (.name == \"$file\") | .id"

# product_file_id=$(pivnet product-files -p p-mysql -r 1.9.4 --format json | jq "'"$jq_string"'")
product_file_id=$(pivnet product-files -p ${PRODUCT} -r ${VERSION} --format json | jq '.[] | select (.name == "'$file'") | .id')

pivnet download-product-files -p ${PRODUCT} -r ${VERSION} -i ${product_file_id}

unzip -q $file

case $1 in
    stemcell)
        awk '/product_version:/ {print} /stemcell/,/version/ {print}' metadata/${product_file}.yml
        ;;
    cf-mysql)
        awk '/file: cf-mysql/,/version: / {print} /product_version: / {print}' metadata/${product_file}.yml
        ;;
esac

exit $?

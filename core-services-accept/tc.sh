#!/bin/sh -x


# aws s3 cp s3://pcf-core-services-artifacts/p-mysql/master/tested/p-mysql-1.9.6.alpha.1172.34c3f99.dirty.pivotal .

product_file="p_mysql.yml"

case $1 in
    stemcell)
        awk '/product_version:/ {print} /stemcell/,/version/ {print}' metadata/${product_file}
        ;;
    *)
        awk "/name: $1/,/version: / {print} /product_version: / {print}" metadata/${product_file}
        ;;
esac


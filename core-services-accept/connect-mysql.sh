#!/bin/sh
#
# Script to connect to a mysql service instance using cf ssh
# Requires you're already logged into cf, and have trivial-js

usage="\
$0 service-instance service-key
"

USE_SSL=0

args=`getopt shx $*`; errcode=$?; set -- $args
if [ 0 -ne $errcode ]; then echo ; echo "$usage" ; exit $errcode ; fi

for i ; do
    case $i in
        -h)
            echo "$usage"
            exit 0
            ;;
        -x)
            echo "Debug mode."
            set -x
            shift ;
            ;;
        -s)
            echo "Using TLS."
            USE_TLS=1 ;
            shift ;
            ;;
    esac
done

if [ "--" = $1 ]; then shift; fi

SERVICE_NAME=$1
SERVICE_KEY=$2
if [ "XX" = "${SERVICE_NAME}XX" -o "XX" = "${SERVICE_KEY}XX" ] ; then
    echo "[ERROR] $usage" ;
    exit 1
fi

# I used to try to cache the service key info, but it was too hard to
# send the string to jq without errors
# SERVICE_KEY_JSON="'"$(cf service-key $SERVICE_NAME $SERVICE_KEY | tail +3)"'"

SERVICE_IP=$(cf service-key $SERVICE_NAME $SERVICE_KEY | tail +3 | jq .hostname | tr -d \")
USER_NAME=$(cf service-key $SERVICE_NAME $SERVICE_KEY | tail +3 | jq .username | tr -d \")
USER_PW=$(cf service-key $SERVICE_NAME $SERVICE_KEY | tail +3 | jq .password | tr -d \")
DATABASE=$(cf service-key $SERVICE_NAME $SERVICE_KEY | tail +3 | jq .name | tr -d \")
if [ $USE_TLS ]; then
    cf service-key $SERVICE_NAME $SERVICE_KEY | tail +3 | jq .ca_certificate | tr -d \" > /tmp/$SERVICE_KEY.crt
    if [ $? ]; then
        CACERT=/tmp/$SERVICE_KEY.crt
        perl -pe 's/\\n/\n/g' -i $CACERT
    fi
fi

LOCK_FILE=$HOME/.${SERVICE_NAME}.tunnel

## FIXME: improvement, accept an optional arg to use an existing app
APP_GUID=$(cf app --guid trivial-js)
if [ 0 != $? ]; then
    echo "trivial-js not running. attempting to push."
    (cd $HOME/workspace/trivial-js ; cf push)
    APP_GUID=$(cf app --guid trivial-js)
    if [ 0 != $? ]; then
        echo "unable to push trivial-js. exiting."
        exit 1
    fi
fi

## FIXME: improvement, allow user to specify local port
function start_tunnel() {
    (touch $LOCK_FILE ; \
     cf ssh -N -L 63306:$SERVICE_IP:3306 trivial-js && rm $LOCK_FILE) &
    echo $! > $LOCK_FILE ;
}

if [ ! -f $LOCK_FILE ]; then
    start_tunnel ;
    trap 'rm -f -- "${LOCK_FILE}"' INT TERM HUP EXIT ;
else
    NUM=$(ps auxww | tail +2 | grep -v grep | grep -c `cat $LOCK_FILE`)
    if [ 1 = $NUM ]; then echo "Tunnel still running.";
    else
        echo "[WARNING] lock file $LOCK_FILE still exists, process gone?"
        start_tunnel ;
    fi
fi

sleep 2 # Necessary to allow tunnel to establish connection

if [ $USE_TLS ]; then
    mysql --ssl --ssl-verify-server-cert --ssl-ca=$CACERT -u${USER_NAME} -p${USER_PW} -h 127.0.0.1 -P 63306 ${DATABASE}
else
    mysql -u${USER_NAME} -p${USER_PW} -h 127.0.0.1 -P 63306 ${DATABASE}
fi

#!/bin/sh
#
# Script to connect to a mysql service instance using cf ssh
# Requires you're already logged into cf, and have trivial-js

usage="\
$0 service-instance service-key
"

args=`getopt hx $*`; errcode=$?; set -- $args
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
    esac
done

if [ "--" = $1 ]; then shift; fi

SERVICE_NAME=$1
SERVICE_KEY=$2
if [ "XX" = "${SERVICE_NAME}XX" -o "XX" = "${SERVICE_KEY}XX" ] ; then
    echo "[ERROR] $usage" ;
    exit 1
fi

SERVICE_KEY_JSON=$(cf service-key $SERVICE_NAME $SERVICE_KEY | tail +3)

SERVICE_IP=$(echo $SERVICE_KEY_JSON | jq .hostname | tr -d \")
USER_NAME=$(echo $SERVICE_KEY_JSON | jq .username | tr -d \")
USER_PW=$(echo $SERVICE_KEY_JSON | jq .password | tr -d \")
DATABASE=$(echo $SERVICE_KEY_JSON | jq .name | tr -d \")
LOCK_FILE=$HOME/.${SERVICE_NAME}.tunnel

## FIXME: improvement, make tis accept an optional arg to use an existing app
APP_GUID=$(cf app --guid trivial-js)
if [ ! $? ]; then
    echo "trivial-js not running. attempting to push."
    cf push $HOME/workspace/trivial-js
    APP_GUID=$(cf app --guid trivial-js)
    if [ ! $? ]; then
        echo "unable to push trivial-js. exiting."
        exit 1
    fi
fi

## FIXME: improvement, allow user to specify local port
function start_tunnel() {
    (touch $LOCK_FILE ; \
     trap 'rm -f -- "$HOME/.${SERVICE_NAME}"' INT TERM HUP EXIT ; \
     cf ssh -N -L 63306:$SERVICE_IP:3306 trivial-js && rm $LOCK_FILE) &
    echo $! > $LOCK_FILE ;
}

if [ ! -f $LOCK_FILE ]; then
    start_tunnel ;
else
    NUM=$(ps auxww | tail +2 | grep -v grep | grep -c `cat $LOCK_FILE`)
    if [ 1 = $NUM ]; then echo "Tunnel still running.";
    else
        echo "[WARNING] lock file $LOCK_FILE still exists, process gone?"
        start_tunnel ;
    fi
fi

sleep 2 # Necessary to allow tunnel to establish connection

mysql -u${USER_NAME} -p${USER_PW} -h 127.0.0.1 -P 63306 ${DATABASE}

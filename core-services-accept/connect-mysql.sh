#!/bin/sh
#
# Script to connect to a mysql service instance using cf ssh
# Requires you're already logged into cf, and have trivial-js

SCRIPT=$(basename $0)

usage="\
${SCRIPT} [-a app_name] [-p port] [-x] service-instance service-key
    -a specify which app to use, default trivial-js.
    -p specify which local port to use, you can run multiple tunnels simultaneously
    -x debug mode
"

USE_SSL=0
APP="trivial-js"
PORT=63306

args=`getopt a:p:shx $*`; errcode=$?; set -- $args
if [ 0 -ne $errcode ]; then echo ; echo "$usage" ; exit $errcode ; fi

for i ; do
    case $i in
        -a)
            APP=$2 ; shift ;
            echo "Using app: $APP"
            shift ;;
        -p)
            PORT=$2 ; shift ;
            echo "Using port: $PORT"
            shift ;;
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
SVC_JSON=`mktemp /tmp/${SCRIPT}.XXXXXX` || exit 1
cf service-key $SERVICE_NAME $SERVICE_KEY | tail +3 > ${SVC_JSON}

SERVICE_IP=$(jq .hostname ${SVC_JSON} | tr -d \")
USER_NAME=$(jq .username ${SVC_JSON} | tr -d \")
USER_PW=$(jq .password ${SVC_JSON} | tr -d \")
DATABASE=$(jq .name ${SVC_JSON} | tr -d \")
if [ $USE_TLS ]; then
    jq .ca_certificate ${SVC_JSON} | tr -d \" > /tmp/$SERVICE_KEY.crt
    if [ $? ]; then
        CACERT=/tmp/$SERVICE_KEY.crt
        perl -pe 's/\\n/\n/g' -i $CACERT
    fi
fi
rm $SVC_JSON ;

LOCK_FILE=$HOME/.${SERVICE_NAME}.tunnel

APP_GUID=$(cf app --guid $APP)

if [ 0 != $? ]; then
    echo "$APP not running. attempting to push."
    (cd $HOME/workspace/trivial-js ; cf push)
    APP_GUID=$(cf app --guid trivial-js)
    if [ 0 != $? ]; then
        echo "unable to push trivial-js. exiting."
        exit 1
    fi
fi

function start_tunnel() {
    (touch $LOCK_FILE ; \
     cf ssh -N -L $PORT:$SERVICE_IP:3306 $APP && rm $LOCK_FILE ; \
     trap 'echo "Removing ${LOCK_FILE}"; rm -f -- "${LOCK_FILE}"' INT TERM HUP EXIT ;) &
    echo $! > $LOCK_FILE ;
}

if [ ! -f $LOCK_FILE ]; then
    start_tunnel ;
    /bin/echo -n "Sleeping to allow tunnel to establish connection... "
    for i in 4 3 2 1; do /bin/echo -n "$i... " ; sleep 1 ; done
    echo

else
    NUM=$(ps auxww | tail +2 | grep -v grep | grep -c `cat $LOCK_FILE`)
    if [ 1 = $NUM ]; then echo "Tunnel still running.";
    else
        echo "[WARNING] lock file $LOCK_FILE still exists, process gone?"
        start_tunnel ;
    fi
fi


if [ $USE_TLS ]; then
    mysql --ssl --ssl-verify-server-cert --ssl-ca=$CACERT -u${USER_NAME} -p${USER_PW} -h127.0.0.1 -P${PORT} ${DATABASE}
else
    mysql -u${USER_NAME} -p${USER_PW} -h127.0.0.1 -P${PORT} ${DATABASE}
fi

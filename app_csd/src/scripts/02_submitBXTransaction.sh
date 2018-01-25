#!/bin/bash

set -x

export PATH=$PATH:/bigf/admin/flink/flink/bin/

APP_HOME_DEFAULT=/bigf/admin/application
APP_NAME_DEFAULT=spdbStreaming-1.1

APP_HOME=${APP_HOME:-$APP_HOME_DEFAULT}
APP_NAME=${APP_NAME-$APP_NAME_DEFAULT}

ppp=$APP_HOME/$APP_NAME

echo "===========ppp:$ppp=============="

function checkRunningApp() {
    local app_name=$1
    for app_id in `flink list | grep -w $app_name | awk '{print $4}'`
    do
        echo "Found Flink App '$app_name' with id '$app_id'"
        echo "Quit without submit App"
        exit -1
    done
    echo "NO Previous Running app '$app_name'"
}

# checkRunningApp BXSceneAdapter
# flink run -c com.spdb.streaming.transaction.FlinkSaveTransaction $ppp/lib/streaming-transaction-1.1.jar --confPath $ppp/conf/BXTransaction.yaml

while true
do
    sleep 3600
done


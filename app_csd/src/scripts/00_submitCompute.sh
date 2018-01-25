#!/usr/bin/env bash

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

checkRunningApp StatRuleCompute

echo "Starting App StatRuleCompute"
flink run -c com.spdb.streaming.compute.StatRuleComputeMain $ppp/lib/streaming-compute-1.1.jar --confPath $ppp/conf/ComputeRule.yaml


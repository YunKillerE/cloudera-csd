#!/bin/bash
export PATH=$PATH:/bigf/admin/flink/flink/bin


flink_app=$1

function killAllFlinkApp() {
    local app_name=$1
    for app_id in `flink list | grep -w $app_name | awk '{print $4}'`
    do
        echo "Found Flink App '$app_name' with id '$app_id'"
        flink cancel $app_id
        echo "Flink App '$app_id' was killed"
    done
    echo "All Flink App with name '$app_name' was killed"
}

LOOP_LIMIT=120
function waitAppDied() {
    local app_name=$1
    
    for i in `seq 1 $LOOP_LIMIT`
    do
        local app_list=`flink list | grep -w $app_name | awk '{print $4}'`
        if [ -z "$app_list" ]
        then
            break
        fi
        sleep 1
    done

    echo "waitAppDied exhausted"
}


for app_name in StatRuleCompute FBXSceneAdapter BXSceneAdapter RecordPreprocessing
do
    killAllFlinkApp $app_name
    waitAppDied $app_name
done


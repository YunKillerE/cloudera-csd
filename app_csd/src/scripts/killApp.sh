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

killAllFlinkApp $flink_app


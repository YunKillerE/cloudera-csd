#!/bin/bash

# for debugging
set -x

# Time marker for both stderr and stdout
date; date 1>&2

echo ""
echo "Date: `date`"

#ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}/" )" && cd .. && pwd )"

DEFAULT_ROOT=/bigf/app/schedule/schedule
ROOT=${SCHEDULE_HOME:-$DEFAULT_ROOT}

cd $ROOT

exec java -cp \
    lib/batch-0.0.1-SNAPSHOT.jar \
    -XX:MaxGCPauseMillis=100 -XX:ParallelGCThreads=8 -XX:ConcGCThreads=2 \
    -XX:+UseG1GC -XX:+HeapDumpOnOutOfMemoryError -verbose:gc -XX:+PrintGCDetails \
    -XX:+PrintGCTimeStamps -XX:+PrintClassHistogram -Xloggc:/bigf/log/batch/batch_dump.log \
    com.spdb.batch.scheduler.zooKeeperScheduler





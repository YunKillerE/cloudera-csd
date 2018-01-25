#!/bin/bash

# for debugging
set -x

# Time marker for both stderr and stdout
date; date 1>&2
id

USER=$(id -u -n)

cmd=$1
timestamp=$(date)

echo ""
echo "Date            : `date`"
echo "HOMST           : $host"
echo "IGNITE_HOME     : $IGNITE_HOME"
echo "FLINK_HOME      : $FLINK_HOME"
echo "FLINK_CONFIG    : $FLINK_CONFIG"
echo "FLINK_LOG_DIR   : $FLINK_LOG_DIR"
echo "USER            : $USER"

# Defaults
DEFAULT_IGNITE_HOME=/bigf/admin/ignite/ignite
DEFAULT_FLINK_HOME=/bigf/admin/flink/flink
DEFAULT_FLINK_CONFIG=/bigf/admin/flink/flink/conf/default-config.xml
DEFAULT_FLINK_LOG_DIR=/bigf/admin/flink/flink/log
DEFAULT_FLINK_IDENT_STRING=bigf_admin

IGNITE_HOME=${IGNITE_HOME:-$DEFAULT_IGNITE_HOME}
FLINK_HOME=${FLINK_HOME:-$DEFAULT_FLINK_HOME}
FLINK_HOME_TMP=${FLINK_HOME}
FLINK_CONFIG=${FLINK_CONFIG:-$DEFAULT_FLINK_CONFIG}
FLINK_DIST=${FLINK_HOME}
FLINK_LOG_DIR=${FLINK_LOG_DIR:-$DEFAULT_FLINK_LOG_DIR}
FLINK_IDENT_STRING=${USER:-$DEFAULT_FLINK_IDENT_STRING}
FLINK_CONF_DIR=${FLINK_HOME}/conf
EXECUTIONMODE=cluster
WEBUIPORT=8081


#
# Set SCRIPTS_HOME - base path to scripts.
#
SCRIPTS_HOME="${FLINK_HOME}/bin"

#source "${SCRIPTS_HOME}"/config.sh

STARTSTOP=`echo $1 | cut -d'-' -f2`
DAEMON=`echo $1 | cut -d'-' -f1`

bin=`dirname "$0"`
bin=`cd "$bin"; pwd`

echo "=========================== ${STARTSTOP} =================================="
echo "=========================== ${DAEMON} =================================="

. "$bin"/config.sh

HOST=${HOSTNAME}
echo ""
echo "cmd: $1"
echo "Date: `date`"
echo "HOST: $HOST"
echo "FLINK_HOME: $FLINK_HOME"
echo "FLINK_CONFIG: $FLINK_CONFIG"


case $DAEMON in
    (jobmanager)
        CLASS_TO_RUN=org.apache.flink.runtime.jobmanager.JobManager
    ;;

    (taskmanager)
        CLASS_TO_RUN=org.apache.flink.runtime.taskmanager.TaskManager
    ;;

    (*)
        echo "Unknown daemon '${DAEMON}'. $USAGE."
        exit 1
    ;;
esac

if [ "$FLINK_IDENT_STRING" = "" ]; then
    FLINK_IDENT_STRING="$USER"
fi

FLINK_TM_CLASSPATH=`constructFlinkClassPath`

pid=$FLINK_PID_DIR/flink-$FLINK_IDENT_STRING-$DAEMON.pid

mkdir -p "$FLINK_PID_DIR"

# Log files for daemons are indexed from the process ID's position in the PID
# file. The following lock prevents a race condition during daemon startup
# when multiple daemons read, index, and write to the PID file concurrently.
# The lock is created on the PID directory since a lock file cannot be safely
# removed. The daemon is started with the lock closed and the lock remains
# active in this script until the script exits.
#command -v flock >/dev/null 2>&1
#if [[ $? -eq 0 ]]; then
#    exec 200<"$FLINK_PID_DIR"
#    flock 200
#fi

# Ascending ID depending on number of lines in pid file.
# This allows us to start multiple daemon of each type.
id=$([ -f "$pid" ] && echo $(wc -l < "$pid") || echo "0")

FLINK_LOG_PREFIX="${FLINK_LOG_DIR}/flink-${FLINK_IDENT_STRING}-${DAEMON}-${id}-${HOSTNAME}"
log="${FLINK_LOG_PREFIX}.log"
out="${FLINK_LOG_PREFIX}.out"

log_setting=("-Dlog.file=${log}" "-Dlog4j.configurationFile=file:${FLINK_CONF_DIR}/log4j2.xml" "-Dlogback.configurationFile=file:${FLINK_CONF_DIR}/logback.xml")

JAVA_VERSION=$(${JAVA_RUN} -version 2>&1 | sed 's/.*version "\(.*\)\.\(.*\)\..*"/\1\2/; 1q')

# Only set JVM 8 arguments if we have correctly extracted the version
if [[ ${JAVA_VERSION} =~ ${IS_NUMBER} ]]; then
    if [ "$JAVA_VERSION" -lt 18 ]; then
        JVM_ARGS="$JVM_ARGS -XX:MaxPermSize=256m"
    fi
fi


case $STARTSTOP in

    (start)
        # Rotate log files
        rotateLogFilesWithPrefix "$FLINK_LOG_DIR" "$FLINK_LOG_PREFIX"

    if [ "${DAEMON}" = "jobmanager" ];then

        if [ -z $EXECUTIONMODE ]; then
            echo "Missing execution mode (local|cluster) argument. $USAGE."
            exit 1
        fi

        if [[ ! ${FLINK_JM_HEAP} =~ $IS_NUMBER ]] || [[ "${FLINK_JM_HEAP}" -lt "0" ]]; then
            echo "[ERROR] Configured JobManager memory size is not a valid value. Please set '${KEY_JOBM_MEM_SIZE}' in ${FLINK_CONF_FILE}."
            exit 1
        fi

        if [ "$EXECUTIONMODE" = "local" ]; then
            if [[ ! ${FLINK_TM_HEAP} =~ $IS_NUMBER ]] || [[ "${FLINK_TM_HEAP}" -lt "0" ]]; then
                echo "[ERROR] Configured TaskManager memory size is not a valid value. Please set ${KEY_TASKM_MEM_SIZE} in ${FLINK_CONF_FILE}."
                exit 1
            fi

            FLINK_JM_HEAP=`expr $FLINK_JM_HEAP + $FLINK_TM_HEAP`
        fi

        if [ "${FLINK_JM_HEAP}" -gt "0" ]; then
            export JVM_ARGS="$JVM_ARGS -Xms"$FLINK_JM_HEAP"m -Xmx"$FLINK_JM_HEAP"m"
        fi

        # Add JobManager-specific JVM options
        export FLINK_ENV_JAVA_OPTS="${FLINK_ENV_JAVA_OPTS} ${FLINK_ENV_JAVA_OPTS_JM}"

        # Startup parameters
        args=("--configDir" "${FLINK_CONF_DIR}" "--executionMode" "${EXECUTIONMODE}")
        if [ ! -z $HOST ]; then
            args+=("--host")
            args+=("${HOST}")
        fi

        if [ ! -z $WEBUIPORT ]; then
            args+=("--webui-port")
            args+=("${WEBUIPORT}")
        fi

            # Evaluate user options for local variable expansion
            FLINK_ENV_JAVA_OPTS=$(eval echo ${FLINK_ENV_JAVA_OPTS})

            echo "============`manglePathList` ====================="

            echo "Starting $DAEMON daemon on host $HOSTNAME."
            #$JAVA_RUN $JVM_ARGS ${FLINK_ENV_JAVA_OPTS} "${log_setting[@]}" -classpath "`manglePathList "$FLINK_TM_CLASSPATH:$INTERNAL_HADOOP_CLASSPATHS"`" ${CLASS_TO_RUN} "${args[@]}"
            exec $JAVA_RUN $JVM_ARGS ${FLINK_ENV_JAVA_OPTS} "${log_setting[@]}" -classpath "`manglePathList "$FLINK_TM_CLASSPATH:$INTERNAL_HADOOP_CLASSPATHS"`" ${CLASS_TO_RUN} "${args[@]}"

    elif [ "${DAEMON}" = "taskmanager" ];then

        # if memory allocation mode is lazy and no other JVM options are set,
        # set the 'Concurrent Mark Sweep GC'
        if [[ $FLINK_TM_MEM_PRE_ALLOCATE == "false" ]] && [ -z "${FLINK_ENV_JAVA_OPTS}" ] && [ -z "${FLINK_ENV_JAVA_OPTS_TM}" ]; then
            export JVM_ARGS="$JVM_ARGS -XX:+UseG1GC"
        fi

        if [[ ! ${FLINK_TM_HEAP} =~ ${IS_NUMBER} ]] || [[ "${FLINK_TM_HEAP}" -lt "0" ]]; then
            echo "[ERROR] Configured TaskManager JVM heap size is not a number. Please set '${KEY_TASKM_MEM_SIZE}' in ${FLINK_CONF_FILE}."
            exit 1
        fi

        if [ "${FLINK_TM_HEAP}" -gt "0" ]; then

            TM_HEAP_SIZE=$(calculateTaskManagerHeapSizeMB)
            # Long.MAX_VALUE in TB: This is an upper bound, much less direct memory will be used
            TM_MAX_OFFHEAP_SIZE="8388607T"

            export JVM_ARGS="${JVM_ARGS} -Xms${TM_HEAP_SIZE}M -Xmx${TM_HEAP_SIZE}M -XX:MaxDirectMemorySize=${TM_MAX_OFFHEAP_SIZE}"

        fi

        # Add TaskManager-specific JVM options
        FLINK_ENV_JAVA_OPTS=$(eval echo ${FLINK_ENV_JAVA_OPTS})
        export FLINK_ENV_JAVA_OPTS="${FLINK_ENV_JAVA_OPTS} ${FLINK_ENV_JAVA_OPTS_TM}"

        # Startup parameters
        args=("--configDir" "${FLINK_CONF_DIR}")


        echo "============`manglePathList` ====================="

        echo "Starting $DAEMON daemon on host $HOSTNAME."
        #$JAVA_RUN $JVM_ARGS ${FLINK_ENV_JAVA_OPTS} "${log_setting[@]}" -classpath "`manglePathList "$FLINK_TM_CLASSPATH:$INTERNAL_HADOOP_CLASSPATHS"`" ${CLASS_TO_RUN} "${args[@]}"
        exec $JAVA_RUN $JVM_ARGS ${FLINK_ENV_JAVA_OPTS} "${log_setting[@]}" -classpath "`manglePathList "$FLINK_TM_CLASSPATH:$INTERNAL_HADOOP_CLASSPATHS"`" ${CLASS_TO_RUN} "${args[@]}"

    else

        echo "${DAEMON} inpurt error"
        exit 1

    fi

       ;;

    (stop)
        if [ -f "$pid" ]; then
            # Remove last in pid file
            to_stop=$(tail -n 1 "$pid")

            if [ -z $to_stop ]; then
                rm "$pid" # If all stopped, clean up pid file
                echo "No $DAEMON daemon to stop on host $HOSTNAME."
            else
                sed \$d "$pid" > "$pid.tmp" # all but last line

                # If all stopped, clean up pid file
                [ $(wc -l < "$pid.tmp") -eq 0 ] && rm "$pid" "$pid.tmp" || mv "$pid.tmp" "$pid"

                if kill -0 $to_stop > /dev/null 2>&1; then
                    echo "Stopping $DAEMON daemon (pid: $to_stop) on host $HOSTNAME."
                    kill $to_stop
                else
                    echo "No $DAEMON daemon (pid: $to_stop) is running anymore on $HOSTNAME."
                fi
            fi
        else
            echo "No $DAEMON daemon to stop on host $HOSTNAME."
        fi
    ;;

    (*)
        echo "Unexpected argument '$STARTSTOP'. $USAGE."
        exit 1
    ;;

esac

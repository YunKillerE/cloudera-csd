#!/bin/bash

# for debugging
set -x

# Time marker for both stderr and stdout
date; date 1>&2

echo ""
echo "Date: `date`"
echo "HOMST: $host"
echo "IGNITE_HOME: $IGNITE_HOME"
echo "IGHITE_CONFIG: $IGNITE_CONFIG"
echo "IGNITE_JVM_OPTS: $IGNITE_JVM_OPTS"
echo "IGNITE_JMX_PORT: $IGNITE_JMX_PORT"

cmd=$1
timestamp=$(date)

DEFAULT_IGNITE_HOME=/bigf/admin/ignite/ignite/
DEFAULT_IGNITE_CONFIG=/bigf/admin/ignite/ignite/config/default-config.xml
IGNITE_HOME=${IGNITE_HOME:-$DEFAULT_IGNITE_HOME}
IGNITE_HOME_TMP=${IGNITE_HOME}
IGNITE_CONFIG=${IGNITE_CONFIG:-$DEFAULT_IGNITE_CONFIG}

#
# Set SCRIPTS_HOME - base path to scripts.
#
SCRIPTS_HOME="${IGNITE_HOME}/bin"

source "${SCRIPTS_HOME}"/include/functions.sh

#
# Discover path to Java executable and check it's version.
#
checkJava

#
# Discover IGNITE_HOME environment variable.
#
setIgniteHome

#
# Set IGNITE_LIBS.
#
. "${SCRIPTS_HOME}"/include/setenv.sh

CP="${IGNITE_LIBS}"

RANDOM_NUMBER=$("$JAVA" -cp "${CP}" org.apache.ignite.startup.cmdline.CommandLineRandomNumberGenerator)

RESTART_SUCCESS_FILE="${IGNITE_HOME}/work/ignite_success_${RANDOM_NUMBER}"
RESTART_SUCCESS_OPT="-DIGNITE_SUCCESS_FILE=${RESTART_SUCCESS_FILE}"

#
# Set JMX Port
#

if [ "$IGNITE_JMX_PORT" -gt "49000" ]; then
    JMX_MON="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=${IGNITE_JMX_PORT} \
        -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false"
else
    # If JMX port wasn't found do not initialize JMX.
    echo "$0, WARN: Ignore invalid JMX Port '$IGNITE_JMX_PORT'"
    JMX_MON=""
fi

#
# JVM options. See http://java.sun.com/javase/technologies/hotspot/vmoptions.jsp for more details.
#
# ADD YOUR/CHANGE ADDITIONAL OPTIONS HERE
#
if [ -z "$IGNITE_JVM_OPTS" ] ; then
    if [[ `"$JAVA" -version 2>&1 | egrep "1\.[7]\."` ]]; then
        IGNITE_JVM_OPTS="-Xms1g -Xmx1g -server -XX:+AggressiveOpts -XX:MaxPermSize=256m"
    else
        IGNITE_JVM_OPTS="-Xms1g -Xmx1g -server -XX:+AggressiveOpts -XX:MaxMetaspaceSize=256m"
    fi
fi

#
# Uncomment the following GC settings if you see spikes in your throughput due to Garbage Collection.
#
# IGNITE_JVM_OPTS="$IGNITE_JVM_OPTS -XX:+UseParNewGC -XX:+UseConcMarkSweepGC -XX:+UseTLAB -XX:NewSize=128m -XX:MaxNewSize=128m"
# IGNITE_JVM_OPTS="$IGNITE_JVM_OPTS -XX:MaxTenuringThreshold=0 -XX:SurvivorRatio=1024 -XX:+UseCMSInitiatingOccupancyOnly -XX:CMSInitiatingOccupancyFraction=60"

#
# Uncomment if you get StackOverflowError.
# On 64 bit systems this value can be larger, e.g. -Xss16m
#
# IGNITE_JVM_OPTS="${IGNITE_JVM_OPTS} -Xss4m"

#
# Uncomment to set preference for IPv4 stack.
#
# IGNITE_JVM_OPTS="${IGNITE_JVM_OPTS} -Djava.net.preferIPv4Stack=true"

#
# Assertions are disabled by default since version 3.5.
# If you want to enable them - set 'ENABLE_ASSERTIONS' flag to '1'.
#
ENABLE_ASSERTIONS="0"

#
# Assertions are disabled by default since version 3.5.
# If you want to enable them - set 'ENABLE_ASSERTIONS' flag to '1'.
#
ENABLE_ASSERTIONS="0"

#
# Set '-ea' options if assertions are enabled.
#
if [ "${ENABLE_ASSERTIONS}" = "1" ]; then
    IGNITE_JVM_OPTS="${IGNITE_JVM_OPTS} -ea"
fi

#
# If this is a Hadoop edition, and HADOOP_HOME set, add the native library location:
#
if [ -d "${IGNITE_HOME}/libs/ignite-hadoop/" ] && [ -n "${HADOOP_HOME}" ] && [ -d "${HADOOP_HOME}/lib/native/" ]; then
   if [[ "${IGNITE_JVM_OPTS}${JVM_XOPTS}" != *-Djava.library.path=* ]]; then
      IGNITE_JVM_OPTS="${IGNITE_JVM_OPTS} -Djava.library.path=${HADOOP_HOME}/lib/native/"
   fi
fi


#
# Set main class to start service (grid node by default).
#
if [ "${MAIN_CLASS}" = "" ]; then
    MAIN_CLASS=org.apache.ignite.startup.cmdline.CommandLineStartup
fi

#
# Remote debugging (JPDA).
# Uncomment and change if remote debugging is required.
#
# IGNITE_JVM_OPTS="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=8787 ${IGNITE_JVM_OPTS}"

ERRORCODE="-1"


netstat -an | grep LIST

if [ "start" = "$cmd" ]; then
  exec "$JAVA" ${IGNITE_JVM_OPTS} ${QUIET} "${RESTART_SUCCESS_OPT}" ${JMX_MON} \
      -DIGNITE_HOME="${IGNITE_HOME}" \
      -DIGNITE_PROG_NAME="$0" ${JVM_XOPTS} -cp "${CP}" ${MAIN_CLASS} "${IGNITE_CONFIG}"
elif [ "stop" = "$cmd" ]; then
  echo "$timestamp Stopping Server"
else
  echo "$timestamp Don't understand [$cmd]"
fi

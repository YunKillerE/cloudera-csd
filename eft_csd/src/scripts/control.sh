#!/bin/bash

# for debugging
set -x

# Time marker for both stderr and stdout
date; date 1>&2

echo ""
echo "Date: `date`"

#ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}/" )" && cd .. && pwd )"

DEFAULT_ROOT=/bigf/app/eft
ROOT=${EFT_HOME:-$DEFAULT_ROOT}

echo "Start Server at root : ${ROOT}"

mkdir -p ${ROOT}/var/log/
mkdir -p ${ROOT}/var/log/eftfiles/
mkdir -p ${ROOT}/var/log/tradelog/

CLASSPATH=$(JARS=("${ROOT}/lib/"/*.jar); IFS=:; echo "${JARS[*]}")
CLASSPATH=${CLASSPATH}:$(hadoop classpath)
# echo "classpath : "
 echo $CLASSPATH

echo "Start Server ..."

exec java \
    -Dlog4j.configuration=file://${ROOT}/EFTServer/etc/log4j.properties \
    -Desb.log.filename=eft_trade.log \
    -Desb.log.filepath=${ROOT}/var/ \
    -Desb.cfg.path=${ROOT}/EFTServer/etc \
    -Deft.file.repo=hdfs://nameservice1/user/upload/eft/sop/ \
    -Deft.kerberos.username=bigf_admin \
    -Deft.kerberos.keytab=/etc/bigf.keytab \
    -cp "${ROOT}/target/eftjava-1.6.1.jar:${CLASSPATH}" \
    com.esb.spdbank.ftp.Main

#!/bin/bash

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}/" )" && pwd )"


for csd_jar in `find dist/target/csd_new-0.1-jar/ -name *.jar`
do
    echo $csd_jar
    scp $csd_jar 10.114.25.159:/opt/cloudera/csd/
    scp $csd_jar 10.114.25.153:/opt/cloudera/csd/
    # scp $csd_jar 10.114.25.125:/opt/cloudera/csd/
    # scp $csd_jar 10.114.25.134:/opt/cloudera/csd/
    # cp $csd_jar ../all_in_one/release_20171220/tools/
done

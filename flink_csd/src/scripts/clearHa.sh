#!/bin/bash
kinit bigf_admin -kt /etc/bigf.keytab
hdfs dfs -rm -r -f /flink/ha/*

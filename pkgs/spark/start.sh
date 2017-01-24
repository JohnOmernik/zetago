#!/bin/bash

APP_MAR_HIST_FILE="${APP_HOME}/marathon_hist.json"
APP_MAR_SHUF_FILE="${APP_HOME}/marathon_shuf.json"

APP_MAR_HIST_ID="${APP_ROLE}/${APP_ID}/sparkhistory"
APP_MAR_SHUF_ID="${APP_ROLE}/${APP_ID}/sparkshuffle"

@go.log INFO "Checking for presense of Spark History Server"
CUR_HIST_STATUS=$(./zeta cluster marathon getinfo $APP_MAR_HIST_ID "ALL" $MARATHON_SUBMIT)
HISTEXISTS=$(echo $CUR_HIST_STATUS|grep "does not exist")
if [ "$HISTEXISTS" != "" ]; then
    @go.log INFO "Spark History Service Does not exist - Submitting and restarting for optimal performace"
    ./zeta cluster marathon submit ${APP_MAR_HIST_FILE} ${MARATHON_SUBMIT} 1
    echo "Waiting 5 seconds for HIST initialization"
    sleep 5
    @go.log INFO "Spark History  Initialization complete"
else
    HISTRUNNING=$(echo $CUR_HIST_STATUS|grep "TASK_RUNNING")
    if [ "$HISTRUNNING" != "" ]; then 
        @go.log FATAL "Spark History for this instance is already on the cluster, and already running, refusing to start anything - exiting"
    else
        @go.log INFO "Spark History for this instance is not running, but is submitted, starting"
        ./zeta cluster marathon scale $APP_MAR_HIST_ID 1 $MARATHON_SUBMIT 1
    fi
fi

echo ""
sleep 2
echo ""

SHUF_INSTS=$(cat $APP_MAR_SHUF_FILE |grep instances|cut -d":" -f2|sed "s/ //g"|sed "s/,//g")

@go.log INFO "Checking for presense of Spark Shuffle Service"
CUR_SHUF_STATUS=$(./zeta cluster marathon getinfo $APP_MAR_SHUF_ID "ALL" $MARATHON_SUBMIT)
SHUFEXISTS=$(echo $CUR_SHUF_STATUS|grep "does not exist")

if [ "$SHUFEXISTS" != "" ]; then
    @go.log INFO "Spark Shuffle Does not exist - Submitting"
    ./zeta cluster marathon submit ${APP_MAR_SHUF_FILE} ${MARATHON_SUBMIT} 1
    @go.log INFO "Spark Shuffle  Initialization complete"
else
    SHUFRUNNING=$(echo $CUR_SHUF_STATUS|grep "TASK_RUNNING")
    if [ "$SHUFRUNNING" != "" ]; then
        @go.log FATAL "Spark Shuffle for this instance is already on the cluster, and already running, refusing to start anything - exiting"
    else
        @go.log INFO "Spark Shuffle for this instance is not running, but is submitted, starting"
        ./zeta cluster marathon scale $APP_MAR_SHUF_ID $SHUF_INSTS $MARATHON_SUBMIT 1
    fi
fi

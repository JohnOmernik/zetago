#!/bin/bash

APP_MAR_HIST_FILE="${APP_HOME}/marathon_hist.json"
APP_MAR_SHUF_FILE="${APP_HOME}/marathon_shuf.json"

APP_MAR_HIST_ID="${APP_ROLE}/${APP_ID}/sparkhistory"
APP_MAR_SHUF_ID="${APP_ROLE}/${APP_ID}/sparkshuffle"


CUR_HIST_STATUS=$(./zeta cluster marathon getinfo $APP_MAR_HIST_ID "ALL" $MARATHON_SUBMIT)
HISTEXISTS=$(echo $CUR_HIST_STATUS|grep "does not exist")
if [ "$HISTEXISTS" == "" ]; then
    HISTRUNNING=$(echo $CUR_HIST_STATUS|grep "TASK_RUNNING")
    if [ "$HISTRUNNING" != "" ]; then
        @go.log INFO "Scalling $APP_ID History Service to 0 instances via $APP_MAR_HIST_ID"
        ./zeta cluster marathon scale $APP_MAR_HIST_ID 0 $MARATHON_SUBMIT 1
    else
        @go.log WARN "History Service for $APP_ID is submitted to Marathon, but doesn't appear to be in a TASK_RUNNING state: Not Stopping - $CUR_HIST_STATUS"
    fi
else
    @go.log WARN "The History Service instance you specified for $APP_ID has not been submitted to Marathon yet, as Marathon reports it doesn't exist"
fi

CUR_SHUF_STATUS=$(./zeta cluster marathon getinfo $APP_MAR_SHUF_ID "ALL" $MARATHON_SUBMIT)
SHUFEXISTS=$(echo $CUR_SHUF_STATUS|grep "does not exist")
if [ "$SHUFEXISTS" == "" ]; then
    SHUFRUNNING=$(echo $CUR_SHUF_STATUS|grep "TASK_RUNNING")
    if [ "$SHUFRUNNING" != "" ]; then
        @go.log INFO "Scalling $APP_ID Shuffle Service to 0 instances via $APP_MAR_SHUF_ID"
        ./zeta cluster marathon scale $APP_MAR_SHUF_ID 0 $MARATHON_SUBMIT 1
    else
        @go.log WARN "Suffle Service for $APP_ID is submitted to Marathon, but doesn't appear to be in a TASK_RUNNING state: Not Stopping - $CUR_SHUF_STATUS"
    fi
else
    @go.log WARN "The Shuffle Service instance you specified for $APP_ID has not been submitted to Marathon yet, as Marathon reports it doesn't exist"
fi



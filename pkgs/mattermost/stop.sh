#!/bin/bash

APP_MAR_APP_FILE="${APP_HOME}/marathon_app.json"
APP_MAR_DB_FILE="${APP_HOME}/marathon_db.json"
APP_MAR_WEB_FILE="${APP_HOME}/marathon_web.json"

APP_MAR_APP_ID="${APP_ROLE}/${APP_ID}/mattermostapp"
APP_MAR_DB_ID="${APP_ROLE}/${APP_ID}/mattermostdb"
APP_MAR_WEB_ID="${APP_ROLE}/${APP_ID}/mattermostweb"

APP_ENV_FILE="/mapr/$CLUSTERNAME/zeta/kstore/env/env_${APP_ROLE}/${APP_NAME}_${APP_ID}.sh"
APP_CERT_LOC="${APP_HOME}/certs"


CUR_WEB_STATUS=$(./zeta cluster marathon getinfo $APP_MAR_WEB_ID "ALL" $MARATHON_SUBMIT)
WEBEXISTS=$(echo $CUR_WEB_STATUS|grep "does not exist")
if [ "$WEBEXISTS" == "" ]; then
    WEBRUNNING=$(echo $CUR_WEB_STATUS|grep "TASK_RUNNING")
    if [ "$WEBRUNNING" != "" ]; then
        @go.log INFO "Scalling $APP_IP mattermost_web to 0 instances via $APP_MAR_WEB_ID"
        ./zeta cluster marathon scale $APP_MAR_WEB_ID 0 $MARATHON_SUBMIT 1
    else
        @go.log WARN "Mattermost Web for $APP_ID is submitted to Marathon, but doesn't appear to be in a TASK_RUNNING state: Not Stopping - $CUR_WEB_STATUS"
    fi
else
    @go.log WARN "The Mattermost Web instance you specified for $APP_ID has not been submitted to Marathon yet, as Marathon reports it doesn't exist"
fi

CUR_APP_STATUS=$(./zeta cluster marathon getinfo $APP_MAR_APP_ID "ALL" $MARATHON_SUBMIT)
APPEXISTS=$(echo $CUR_APP_STATUS|grep "does not exist")
if [ "$APPEXISTS" == "" ]; then
    APPRUNNING=$(echo $CUR_APP_STATUS|grep "TASK_RUNNING")
    if [ "$APPRUNNING" != "" ]; then
        @go.log INFO "Scalling $APP_IP mattermost_app to 0 instances via $APP_MAR_APP_ID"
        ./zeta cluster marathon scale $APP_MAR_APP_ID 0 $MARATHON_SUBMIT 1
    else
        @go.log WARN "Mattermost App for $APP_ID is submitted to Marathon, but doesn't appear to be in a TASK_RUNNING state: Not Stopping - $CUR_APP_STATUS"
    fi
else
    @go.log WARN "The Mattermost App instance you specified for $APP_ID has not been submitted to Marathon yet, as Marathon reports it doesn't exist"
fi

CUR_DB_STATUS=$(./zeta cluster marathon getinfo $APP_MAR_DB_ID "ALL" $MARATHON_SUBMIT)
DBEXISTS=$(echo $CUR_DB_STATUS|grep "does not exist")
if [ "$DBEXISTS" == "" ]; then
    DBRUNNING=$(echo $CUR_DB_STATUS|grep "TASK_RUNNING")
    if [ "$DBRUNNING" != "" ]; then
        @go.log INFO "Scalling $APP_IP mattermost_db to 0 instances via $APP_MAR_DB_ID"
        ./zeta cluster marathon scale $APP_MAR_DB_ID 0 $MARATHON_SUBMIT 1
    else
        @go.log WARN "Mattermost DB for $APP_ID is submitted to Marathon, but doesn't appear to be in a TASK_RUNNING state: Not Stopping - $CUR_DB_STATUS"
    fi
else
    @go.log WARN "The Mattermost DB instance you specified for $APP_ID has not been submitted to Marathon yet, as Marathon reports it doesn't exist"
fi



#!/bin/bash

APP_MAR_APP_FILE="${APP_HOME}/marathon_app.json"
APP_MAR_DB_FILE="${APP_HOME}/marathon_db.json"
APP_MAR_WEB_FILE="${APP_HOME}/marathon_web.json"

APP_MAR_APP_ID="${APP_ROLE}/${APP_ID}/mattermostapp"
APP_MAR_DB_ID="${APP_ROLE}/${APP_ID}/mattermostdb"
APP_MAR_WEB_ID="${APP_ROLE}/${APP_ID}/mattermostweb"

APP_ENV_FILE="/mapr/$CLUSTERNAME/zeta/kstore/env/env_${APP_ROLE}/${APP_NAME}_${APP_ID}.sh"
APP_CERT_LOC="${APP_HOME}/certs"

@go.log INFO "Checking for presense of Mattermost DB"
CUR_DB_STATUS=$(./zeta cluster marathon getinfo $APP_MAR_DB_ID $MARATHON_SUBMIT)
DBEXISTS=$(echo $CUR_DB_STATUS|grep "does not exist")
if [ "$DBEXISTS" != "" ]; then
    @go.log INFO "Mattermost DB Does not exist - Submitting and restarting for optimal performace"
    ./zeta cluster marathon submit ${APP_MAR_DB_FILE} ${MARATHON_SUBMIT} 1
    echo "Waiting 30 seconds for DB initialization"
    sleep 30
    @go.log INFO "Since this was the the first submission, we are now restarting the instance to allow for memory settings to take effect - Stopping DB"
    ./zeta cluster marathon scale ${APP_MAR_DB_ID} 0 $MARATHON_SUBMIT 1
    sleep 3
    @go.log INFO "Starting Marathon DB Instance for $APP_ID"
    ./zeta cluster marathon scale ${APP_MAR_DB_ID} 1 $MARATHON_SUBMIT 1
    @go.log INFO "DB Initialization complete"
else
    DBRUNNING=$(echo $CUR_DB_STATUS|grep "TASK_RUNNING")
    if [ "$DBRUNNING" != "" ]; then 
        @go.log FATAL "Mattermost DB for this instance is already on the cluster, and already running, refusing to start anything - exiting"
    else
        @go.log INFO "Mattermost DB for this instance is not running, but is submitted, starting"
        ./zeta cluster marathon scale $APP_MAR_DB_ID 1 $MARATHON_SUBMIT 1
    fi
fi

echo ""
echo "Waiting 5 seconds"
sleep 5
echo ""


@go.log INFO "Checking for presense of Mattermost APP Server"
CUR_APP_STATUS=$(./zeta cluster marathon getinfo $APP_MAR_APP_ID $MARATHON_SUBMIT)
APPEXISTS=$(echo $CUR_APP_STATUS|grep "does not exist")

if [ "$APPEXISTS" != "" ]; then
    @go.log INFO "Mattermost App Does not exist - Submitting"
    ./zeta cluster marathon submit ${APP_MAR_APP_FILE} ${MARATHON_SUBMIT} 1
    @go.log INFO "Mattermost App Initialization complete"
else
    APPRUNNING=$(echo $CUR_APP_STATUS|grep "TASK_RUNNING")
    if [ "$APPRUNNING" != "" ]; then
        @go.log FATAL "Mattermost App for this instance is already on the cluster, and already running, refusing to start anything - exiting"
    else
        @go.log INFO "Mattermost App for this instance is not running, but is submitted, starting"
        ./zeta cluster marathon scale $APP_MAR_APP_ID 1 $MARATHON_SUBMIT 1
    fi
fi

echo ""
echo "Waiting 5 seconds"
sleep 5
echo ""

@go.log INFO "Checking for presense of Mattermost APP Server"

CUR_WEB_STATUS=$(./zeta cluster marathon getinfo $APP_MAR_WEB_ID $MARATHON_SUBMIT)
WEBEXISTS=$(echo $CUR_WEB_STATUS|grep "does not exist")

if [ "$WEBEXISTS" != "" ]; then
    @go.log INFO "Mattermost Web Does not exist - Submitting"
    ./zeta cluster marathon submit ${APP_MAR_WEB_FILE} ${MARATHON_SUBMIT} 1
    @go.log INFO "Mattermost Web Initialization complete"
else
    WEBRUNNING=$(echo $CUR_WEB_STATUS|grep "TASK_RUNNING")
    if [ "$WEBRUNNING" != "" ]; then
        @go.log FATAL "Mattermost Web for this instance is already on the cluster, and already running, refusing to start anything - exiting"
    else
        @go.log INFO "Mattermost Web for this instance is not running, but is submitted, starting"
        ./zeta cluster marathon scale $APP_MAR_WEB_ID 1 $MARATHON_SUBMIT 1
    fi
fi




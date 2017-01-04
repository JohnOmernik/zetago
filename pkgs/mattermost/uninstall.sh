#!/bin/bash

APP_MAR_APP_FILE="${APP_HOME}/marathon_app.json"
APP_MAR_DB_FILE="${APP_HOME}/marathon_db.json"
APP_MAR_WEB_FILE="${APP_HOME}/marathon_web.json"

APP_MAR_APP_ID="${APP_ROLE}/${APP_ID}/mattermostapp"
APP_MAR_DB_ID="${APP_ROLE}/${APP_ID}/mattermostdb"
APP_MAR_WEB_ID="${APP_ROLE}/${APP_ID}/mattermostweb"

APP_ENV_FILE="/mapr/$CLUSTERNAME/zeta/kstore/env/env_${APP_ROLE}/${APP_NAME}_${APP_ID}.sh"
APP_CERT_LOC="${APP_HOME}/certs"

if [ "$UNATTEND" == "1" ]; then
    CONFIRM="Y"
else
    echo ""
    echo "You have requested to uninstall the instance $APP_ID in role $APP_ROLE of the applicaiton $APP_NAME"
    echo "Uninstall stops the app, removes it from Marathon, and removes the ENV files for the application but leaves data/conf available"
    echo ""
    if [ "$DESTROY" == "1" ]; then
        echo ""
        echo "********************************"
        echo ""
        echo "You have also selected to destroy and delete all data for this app in addition to uninstalling from the ENV variables and marathon" 
        echo ""
        echo "This is irreversible"
        echo ""
        echo "********************************"
        echo ""
    fi

    read -e -p "Are you sure you wish to go on with this action? " -i "N" CONFIRM
fi

if [ "$CONFIRM" == "Y" ]; then
    @go.log WARN "Proceeding with uninstall of $APP_ID"

    @go.log INFO "Stopping $APP_ID"
    ./zeta package stop $CONF_FILE

    @go.log INFO "Removing ENV file at $APP_ENV_FILE"
    rm $APP_ENV_FILE

    @go.log INFO "Destroying $APP_MAR_WEB_ID in marathon"
    ./zeta cluster marathon destroy $APP_MAR_WEB_ID $MARATHON_SUBMIT 1
    @go.log INFO "Destroying $APP_MAR_APP_ID in marathon"
    ./zeta cluster marathon destroy $APP_MAR_APP_ID $MARATHON_SUBMIT 1
    @go.log INFO "Destroying $APP_MAR_DB_ID in marathon"
    ./zeta cluster marathon destroy $APP_MAR_DB_ID $MARATHON_SUBMIT 1
    if [ "$DESTROY" == "1" ]; then
       @go.log WARN "Also removing all data for app"
       @go.log WARN "If volumes exist, we need to handle those"
       sudo rm -rf $APP_HOME
   fi
else
    @go.log WARN "User canceled uninstall"
fi


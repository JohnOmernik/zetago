#!/bin/bash



 CUR_STATUS=$(./zeta cluster marathon getinfo $APP_MAR_ID $MARATHON_SUBMIT)
 EXISTS=$(echo $CUR_STATUS|grep "does not exist")


if [ "$EXISTS" == "" ]; then
    RUNNING=$(echo $CUR_STATUS|grep "TASK_RUNNING")
    if [ "$RUNNING" != "" ]; then
        BROKER_CONF="$APP_HOME/broker.conf"
        if [ ! -f "$BROKER_CONF" ]; then
            @go.log FATAL "Can't find broker.conf at $BROKER_CONF exiting"
        fi
        . $BROKER_CONF
        for X in $(seq 1 $BROKER_COUNT); do
            @go.log INFO "Attempting to Stop Broker $X"
            ./kafka-mesos.sh broker start $X
        done
        sleep 2
        @go.log INFO "Scaling $APP_ID to 0 instances via $APP_MAR_ID"
        ./zeta cluster marathon scale $APP_MAR_ID 0 $MARATHON_SUBMIT 1
    else
        @go.log WARN "App $APP_ID is submitted to Marathon, but doesn't appear to be in a TASK_RUNNING state: Not Stopping - $CUR_STATUS"
    fi
else
    @go.log WARN "The instance you specified, $APP_ID has not been submitted to Marathon yet, as Marathon reports it doesn't exist"
fi




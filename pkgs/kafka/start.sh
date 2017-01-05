#!/bin/bash




CUR_STATUS=$(./zeta cluster marathon getinfo $APP_MAR_ID $MARATHON_SUBMIT)

EXISTS=$(echo $CUR_STATUS|grep "does not exist")

SUBMIT="0"
START="0"

if [ "$EXISTS" == "" ]; then
    RUNNING=$(echo $CUR_STATUS|grep "TASK_RUNNING")
    if [ "$RUNNING" != "" ]; then
        @go.log WARN "Task $APP_MAR_ID already exists on cluster and is in a TASK_RUNNING state. Will not attempt to start"
    else
        START="1"
    fi
else
    SUBMIT="1"
fi
if [ "$SUBMIT" == "1" ]; then
    ./zeta cluster marathon submit $APP_MAR_FILE $MARATHON_SUBMIT 1
    @go.log INFO "Submitting $APP_ID as it hasn't been submitted yet"
fi
if [ "$START" == "1" ]; then
    @go.log INFO "Starting $APP_ID and scaling to 1"
    ./zeta cluster marathon scale $APP_MAR_ID 1 $MARATHON_SUBMIT 1
fi
# Fix Java
. /etc/environment
PATH=$PATH:$JAVA_HOME/bin

KAFKA_MESOS="cd $APP_HOME/kafka-mesos && ./kafka-mesos.sh"

BROKERS=$($KAFKA_MESOS broker list)

if [ "$BROKERS" == "no brokers" ]; then
    @go.log INFO "No brokers - Add some - $BROKERS"
else
    @go.log INFO "Brokers found - $BROKERS"
fi

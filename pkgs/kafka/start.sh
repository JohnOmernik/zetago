#!/bin/bash

. "$_GO_USE_MODULES" 'libmapr'


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
    @go.log INFO "Starting $APP_ID and scaling to $APP_CNT"
    ./zeta cluster marathon scale $APP_MAR_ID $APP_CNT $MARATHON_SUBMIT 1
fi
sleep 5

# Fix Java
. /etc/environment
PATH=$PATH:$JAVA_HOME/bin

APP_USER="zetasvc${APP_ROLE}"
APP_GROUP="zeta${APP_ROLE}${APP_DIR}"
BROKER_CONF="$APP_HOME/brokers.conf"

if [ ! -f "$BROKER_CONF" ]; then
    @go.log INFO "No broker conf - Assuming no brokers and now we will create the conf"
    echo "What setting should we use for heap space for each broker (in MB)?"
    read -e -p "Heap Space: " -i "1024" BROKER_HEAP
    echo ""
    echo "How much memory per broker (separate from heap) should we use (in MB)?"
    read -e -p "Broker Memory: " -i "2048" BROKER_MEM
    echo ""
    echo "How many CPU vCores should we use per broker?"
    read -e -p "Broker CPU(s): " -i "1" BROKER_CPU
    echo ""
    echo "How many kafka brokers do you want running in this instance?"
    read -e -p "Number of Brokers: " -i "3" BROKER_COUNT

    echo "You want ${BROKER_COUNT} broker(s) running, each using ${BROKER_HEAP} mb of heap, ${BROKER_MEM} mb of memory, and ${BROKER_CPU} cpu(s)"
    echo ""
    read -e -p "Is this summary correct? (Y/N): " -i "Y" ANS

    if [ "${ANS}" != "Y" ]; then
        @go.log FATAL "You did not answer Y - exiting"
    fi
    @go.log INFO "Writing Broker Configuration to $BROKER_CONF"

cat > $BROKER_CONF << EOB
#!/bin/bash
BROKER_HEAP="$BROKER_HEAP"
BROKER_MEM="$BROKER_MEM"
BROKER_CPU="$BROKER_CPU"
BROKER_COUNT="$BROKER_COUNT"
EOB

else
    . $BROKER_CONF
fi

cd $APP_HOME/kafka-mesos
BROKERS=$(cd $APP_HOME/kafka-mesos && ./kafka-mesos.sh broker list)
if [ "$BROKERS" == "no brokers" ]; then
    @go.log INFO "Brokers not added yet, adding"
    for X in $(seq 1 $BROKER_COUNT); do

        @go.log INFO "Adding broker${X}"
        BROKER="broker${X}"
        VOL="${APP_DIR}.${APP_ROLE}.${APP_ID}.${BROKER}"

        MNT="/${APP_DIR}/${APP_ROLE}/${APP_NAME}/${APP_ID}/brokerdata/${BROKER}"
        NFSLOC="${APP_HOME}/brokerdata/${BROKER}/"

        maprapi "/volume/create?name=${VOL}&path=${MNT}&rootdirperms=775&user=${IUSER}:fc,a,dump,restore,m,d%20mapr:fc,a,dump,restore,m,d%20${APP_USER}:fc,a,dump,restore,m,d&ae=${APP_USER}" "2"

        T=""
        while [ "$T" == "" ]; do
            sleep 1
            T=$(ls -1 ${APP_HOME}/brokerdata|grep $BROKER)
        done
        sudo chown ${APP_USER}:${APP_GROUP} $NFSLOC
        ./kafka-mesos.sh broker add $X
        ./kafka-mesos.sh broker update $X --cpus ${BROKER_CPU} --heap ${BROKER_HEAP} --mem ${BROKER_MEM} --options log.dirs=${NFSLOC},delete.topic.enable=true

    done
fi

for X in $(seq 1 $BROKER_COUNT); do

    @go.log INFO "Attempting to Start Broker $X"
    ./kafka-mesos.sh broker start $X
done

cd $MYDIR


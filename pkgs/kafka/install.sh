#!/bin/bash


###############
# $APP Specific
echo "The next step will walk through instance defaults for ${APP_ID}"
echo ""

SOME_COMMENTS="Ports for kafka-mesos API"
PORTSTR="CLUSTER:tcp:21000:${APP_ROLE}:${APP_ID}:$SOME_COMMENTS"

getport "CHKADD" "$SOME_COMMENTS" "$SERVICES_CONF" "$PORTSTR"

if [ "$CHKADD" != "" ]; then
    getpstr "MYTYPE" "MYPROTOCOL" "APP_PORT" "MYROLE" "MYAPP_ID" "MYCOMMENTS" "$CHKADD"
    APP_PORTSTR="$CHKADD"
else
    @go.log FATAL "Failed to get Port for $APP_NAME $PSTR"
fi

portslist "APP_PORT_LIST" "${APP_PORTSTR}"
haproxylabel "APP_HA_PROXY" "${APP_PORTSTR}"



read -e -p "Please enter the CPU shares to use with the kafka-mesos scheduler: " -i "1.0" APP_CPU
echo ""
read -e -p "Please enter the Marathon Memory limit to use with kafka-mesos scheduler: " -i "3072" APP_MEM
echo ""
echo "Running Kafka as zetasvc$APP_ROLE"
APP_USER="zetasvc$APP_ROLE"
echo ""
echo "Setting this to use 1 instance"
APP_CNT="1"
##########



APP_MAR_FILE="${APP_HOME}/marathon.json"
APP_ENV_FILE="$CLUSTERMOUNT/zeta/kstore/env/env_${APP_ROLE}/${APP_NAME}_${APP_ID}.sh"

mkdir -p ${APP_HOME}/brokerdata

JAVA_TGZ="mesos-java.tgz"
cd ${APP_HOME}
cp ${APP_PKG_DIR}/${APP_TGZ} ./
tar zxf $APP_TGZ


APP_DOMAIN="marathon.slave.mesos"

cat > ${APP_HOME}/kafka-mesos/kafka-mesos.properties << EOF
# Scheduler options defaults. See ./kafka-mesos.sh help scheduler for more details
debug=false

framework-name=${APP_ID}

master=leader.mesos:5050

user=$APP_USER

storage=zk:/kafka-mesos

jre=${JAVA_TGZ}
# Need the /kafkaprod as the chroot for zk
zk=${ZETA_ZKS}/${APP_ID}

# Need different port for each framework
api=http://${APP_ID}-${APP_ROLE}.${APP_DOMAIN}:${APP_PORT}

#principal=${ROLE_PRIN}

#secret=${ROLE_PASS}

EOF


#echo "Untarring Kafka Mesos Package"
#echo ""
#APP_TGZ="${APP_ID}-runnable.tgz"
#tar zcf ./$APP_TGZ kafka-mesos/
#rm ${APP_BASE_FILE}


cat > $APP_ENV_FILE << EOL1
#!/bin/bash
export ZETA_${APP_ID}_ENV="${APP_ID}"
export ZETA_${APP_ID}_ZK="${ZETA_ZKS}/${APP_ID}"
export ZETA_${APP_ID}_API_PORT="${APP_PORT}"
EOL1



portslist "APP_PORT_LIST" "${APP_PORTSTR}"
haproxylabel "APP_HA_PROXY" "${APP_PORTSTR}"
cat > $APP_MAR_FILE << EOL
{
  "id": "${APP_MAR_ID}",
  "instances": $APP_CNT,
  "cpus": ${APP_CPU},
  "mem": ${APP_MEM},
  "cmd": "export PATH=\`pwd\`/jre/bin:\$PATH && cd kafka-mesos && ./kafka-mesos.sh scheduler ../kafka-mesos.properties",
  "user": "${APP_USER}",
  $APP_PORT_LIST
  "labels": {
   $APP_HA_PROXY
   "CONTAINERIZER":"Mesos"
  },
  "env": {
    "JAVA_LIBRARY_PATH": "/opt/mesosphere/lib",
    "MESOS_NATIVE_JAVA_LIBRARY": "/opt/mesosphere/lib/libmesos.so",
    "LD_LIBRARY_PATH": "/opt/mesosphere/lib",
    "JAVA_HOME": "jre"
  },
  "uris": ["file://${APP_HOME}/${APP_TGZ}", "file://${APP_HOME}/kafka-mesos/${JAVA_TGZ}" , "file://${APP_HOME}/kafka-mesos/kafka-mesos.properties"]
}
EOL

SCMD="./zeta package start $APP_CONF_FILE"

cd $MYDIR
##########
# Provide instructions for next steps
echo ""
echo ""
echo "$APP_NAME instance ${APP_ID} installed at ${APP_HOME} and ready to go"
echo "To start please run: "
echo ""
echo "$ $SCMD"
echo ""



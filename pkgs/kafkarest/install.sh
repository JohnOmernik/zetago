#!/bin/bash

###############
# $APP Specific
echo "The next step will walk through instance defaults for ${APP_ID}"
echo ""

SOME_COMMENTS="Port for kafka rest api port"
PORTSTR="CLUSTER:tcp:28101:${APP_ROLE}:${APP_ID}:$SOME_COMMENTS"
getport "CHKADD" "$SOME_COMMENTS" "$SERVICES_CONF" "$PORTSTR"

if [ "$CHKADD" != "" ]; then
    getpstr "MYTYPE" "MYPROTOCOL" "APP_PORT" "MYROLE" "MYAPP_ID" "MYCOMMENTS" "$CHKADD"
    APP_PORTSTR="$CHKADD"
else
    @go.log FATAL "Failed to get Port for $APP_NAME $PSTR"
fi

bridgeports "APP_PORT_JSON", "$APP_PORT", "$APP_PORTSTR"
haproxylabel "APP_HA_PROXY" "${APP_PORTSTR}"








read -e -p "Please enter the memory limit for the ${APP_ID} instance of ${APP_NAME}: " -i "768" APP_MEM

read -e -p "Please enter the cpu limit for the ${APP_ID} instance of ${APP_NAME}: " -i "1.0" APP_CPU

read -e -p "How many instances of kafkarest do you want to run? " -i "1" APP_CNT

echo "Kafkarest requires an already running instace of kafka to work with.  Please provide a appid.conf file for the kafka instance for this to run against."
echo "This is normally localted in the APP_HOME, so if you have an instead of kafka named kafkaprod running in the role prod, your file would be located: "
echo ""
echo "/mapr/$CLUSTERNAME/zeta/prod/kafka/kafkaprod/kafkaprod.conf"
echo ""
echo "This is REQUIRED"
echo ""
read -e -p "What is the instance name of Kafka will this instance of ${APP_NAME} be running against: "  APP_KAFKA_CONF
if [ ! -f "$APP_KAFKA_CONF" ]; then
    @go.log WARN "That Kafka Conf does not exist, please try again"
    while [ ! -f "${APP_KAFKA_CONF}" ]; do
        read -e -p "Conf file not found, please re-enter the path to conf file for the kafka instance this instance of ${APP_NAME} be running against: " APP_KAFKA_CONF
    done
fi

@go.log INFO "Getting info from Kafka Install"
KAFKA_ENV_FILE=$(cat $APP_KAFKA_CONF|grep "APP_ENV_FILE"|cut -d"=" -f2|sed "s/\"//g")
KAFKA_ID=$(cat $APP_KAFKA_CONF|grep "APP_ID"|cut -d"=" -f2|sed "s/\"//g")
KAFKA_ZKS=$(cat $KAFKA_ENV_FILE|grep "ZETA_${KAFKA_ID}_ZK"|cut -d"=" -f2|sed "s/\"//g")

echo ""
echo ""
echo "Kafka rest can also run against an instance of Schema registry to help with AVRO based kafka records.  This is not required"
echo "However, without a Schema registry, kafkarest will only support raw json based records (no Avro)"

read -e -p "What is the path to the conf file for the instance of schema registry that this instance of ${APP_NAME} be running against (none - for json only mode): " -i "none" APP_SCHEMA_REG_CONF
if [ ! -f "$APP_SCHEMA_REG_CONF" ] && [ "$APP_SCHEMA_REG_CONF" != "none" ]; then
    @go.log WARN "That schema reg Conf does not exist, please try again"
    while [ ! -f "${APP_SCHEMA_REG_CONF}" ] && [ "$APP_SCHEMA_REG_CONF" != "none" ]; do
        read -e -p "Conf file not found, please re-enter the path to conf file for the schema registry instance this instance of ${APP_NAME} be running against (or none for json only): " -i "none" APP_SCHEMA_REG_CONF
    done
fi
echo ""
echo ""

if [ "${APP_SCHEMA_REG_CONF}" != "none" ]; then
    SCHEMA_ENV_FILE=$(cat $APP_SCHEMA_REG_CONF|grep "APP_ENV_FILE"|cut -d"=" -f2|sed "s/\"//g")
    SCHEMA_ID=$(cat $APP_SCHEMA_REG_CONF|grep "APP_ID"|cut -d"=" -f2|sed "s/\"//g")
    SCHEMA_PORT=$(cat $SCHEMA_ENV_FILE|grep "ZETA_${SCHEMA_ID}_PORT"|cut -d"=" -f2|sed "s/\"//g")
    SCHEMA_HOST=$(cat $SCHEMA_ENV_FILE|grep "ZETA_${SCHEMA_ID}_HOST"|cut -d"=" -f2|sed "s/\"//g")
    SCHEMA_PROTO=$(cat $SCHEMA_ENV_FILE|grep "ZETA_${SCHEMA_ID}_PROTO"|cut -d"=" -f2|sed "s/\"//g")

    APP_SCHEMA_REG_URL="schema.registry.url=${SCHEMA_PROTO}://${SCHEMA_HOST}:${SCHEMA_PORT}"
else
   APP_SCHEMA_REG_URL=""
fi

APP_MAR_FILE="${APP_HOME}/marathon.json"
APP_ENV_FILE="/mapr/$CLUSTERNAME/zeta/kstore/env/env_${APP_ROLE}/${APP_NAME}_${APP_ID}.sh"
APP_CONF_DIR="${APP_HOME}/conf"
mkdir -p $APP_CONF_DIR

APP_DOMAIN="marathon.slave.mesos"
cat > ${APP_ENV_FILE} << EOL1
#!/bin/bash
export ZETA_${APP_ID}_ENV="${APP_ID}"
export ZETA_${APP_ID}_HOST="${APP_ID}-${APP_ROLE}.${APP_DOMAIN}"
export ZETA_${APP_ID}_PORT="${APP_PORT}"
EOL1


echo ""
echo "Creating Config"

cat > ${APP_CONF_DIR}/kafka-rest.properties << EOF
${APP_SCHEMA_REG_URL}
zookeeper.connect=${KAFKA_ZKS}
host.name=${APP_ID}.${APP_ROLE}.${APP_DOMAIN}
listeners=http://0.0.0.0:${APP_PORT}
EOF


cat > ${APP_CONF_DIR}/runrest.sh << EOU
#!/bin/bash

CONF_LOC="/app/${APP_VER_DIR}/etc/kafka-rest"
NEW_CONF="/conf_new"

mkdir \$NEW_CONF
cp \${CONF_LOC}/* \${NEW_CONF}/

echo "id=\$HOSTNAME" >> \${NEW_CONF}/kafka-rest.properties
EOU

chmod +x ${APP_CONF_DIR}/runrest.sh


cat > $APP_MAR_FILE << EOL
{
  "id": "${APP_MAR_ID}",
  "cpus": $APP_CPU,
  "mem": $APP_MEM,
  "cmd":"/app/${APP_VER_DIR}/etc/kafka-rest/runrest.sh && /app/${APP_VER_DIR}/bin/kafka-rest-start /conf_new/kafka-rest.properties",
  "instances": ${APP_CNT},
  "labels": {
   $APP_HA_PROXY
   "CONTAINERIZER":"Docker"
  },
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${APP_IMG}",
      "network": "BRIDGE",
      "portMappings": [
        $APP_PORT_JSON
      ]
    },
  "volumes": [
      {
        "containerPath": "/app/${APP_VER_DIR}/etc/kafka-rest",
        "hostPath": "${APP_CONF_DIR}",
        "mode": "RW"
      }
    ]
  }
}

EOL


##########
# Provide instructions for next steps
echo ""
echo ""
echo "$APP_NAME instance ${APP_ID} installed at ${APP_HOME} and ready to go"
echo "To start please run: "
echo ""
echo "$ ./zeta package start ${APP_HOME}/$APP_ID.conf"
echo ""



#!/bin/bash


FS_LIB="lib${FS_PROVIDER}"
. "$_GO_USE_MODULES" $FS_LIB

###############
# $APP Specific
echo "The next step will walk through instance defaults for ${APP_ID}"
echo ""
read -e -p "Please enter the CPU shares for each instance of $APP_NAME: " -i "2.0" APP_CPU
echo ""
echo "----------------------"
echo "Elastic Search Memory Notes:"
echo ""
echo "Elastic Search docs indicate using no more than half the available memory on a node, this is a bit different with mesos/zeta"
echo ""
echo "We will do this: Please enter the amount of Memory for Elastic search here in GB as an integer (1, 2, 4, 8 etc. ES Docs say don't exceed 32)"
echo ""
echo "We will Add 1G for FS cache. Then we will multiply by 1024 to get Marathon Memory"
echo "So if you enter 4, the ES heap will be 4G, the total node memory will be 5G, and the marathon limit will be 5120)"
echo ""
read -e -p "Please enter the ES HEAP size to use, as an int (no G): " -i "4" APP_ES_MEM
APP_TOTAL=$(( $APP_ES_MEM + 1 ))
APP_ES_HEAP="${APP_ES_MEM}g"
APP_MEM=$(( $APP_TOTAL * 1024 ))
echo ""
echo ""
echo "####################################################################"
echo "Swap Control"
echo ""
echo "ES recommends you disable swap, this is interesting, since we are trying to fit more into a cluster, disabling swap, can have issues (potentially)"
echo "However, not disabling can lead to performance issues"
echo ""
echo "We recommend disabling, but monitoring closely for any issues"
echo "This does add security capbilities to the docker container running: They are:"
echo ""
echo "--ulimit memlock=-1:-1"
echo ""
echo "and"
echo ""
echo "--cap-add=IPC_LOCK"
echo""
read -e -p "Do you wish to disable swap on your ES containers?" -i "Y" APP_DISABLE_SWAP
if [ "$APP_DISABLE_SWAP" == "Y" ]; then
    APP_PARAM="\"parameters\": ["$'\n'
    APP_PARAM="${APP_PARAM}{ \"key\": \"ulimit\", \"value\": \"memlock=-1:-1\" },"$'\n'
    APP_PARAM="${APP_PARAM}{ \"key\": \"cap-add\", \"value\": \"IPC_LOCK\" }"$'\n'
    APP_PARAM="${APP_PARAM}],"$'\n'
    APP_SWAP_CONF="bootstrap.mlockall: true"

else
    APP_PARAM="\"parameters\":[],"
    APP_SWAP_CONF=""

fi

read -e -p "How many ES nodes will be part of this cluster? " -i "2" APP_CNT
echo ""
read -e -p "User to run ES nodes: " -i "zetasvc${APP_ROLE}" "APP_USER"
echo ""
read -e -p "Please enter the ES Cluster name: " -i "ZETA${APPROLE}ES" "APP_CLUSTER_NAME"


PCOMMENT="Port for ES $APP_ID HTTP Port"
PORTSTR="CLUSTER:tcp:9200:${APP_ROLE}:${APP_ID}:$PCOMMENT"
getport "CHKADD" "$PCOMMENT" "$SERVICES_CONF" "$PORTSTR"

if [ "$CHKADD" != "" ]; then
    getpstr "MYTYPE" "MYPROTOCOL" "APP_HTTP_PORT" "MYROLE" "MYAPP_ID" "MYCOMMENTS" "$CHKADD"
    APP_HTTP_PORTSTR="$CHKADD"
else
    @go.log FATAL "Failed to get Port for $APP_NAME instance $APP_ID with $PSTR"
fi

PCOMMENT="Port for ES $APP_ID Transport Port"
PORTSTR="CLUSTER:tcp:9300:${APP_ROLE}:${APP_ID}:$PCOMMENT"
getport "CHKADD" "$PCOMMENT" "$SERVICES_CONF" "$PORTSTR"

if [ "$CHKADD" != "" ]; then
    getpstr "MYTYPE" "MYPROTOCOL" "APP_TRANSPORT_PORT" "MYROLE" "MYAPP_ID" "MYCOMMENTS" "$CHKADD"
    APP_TRANSPORT_PORTSTR="$CHKADD"
else
    @go.log FATAL "Failed to get Port for $APP_NAME instance $APP_ID with $PSTR"
fi



bridgeports "APP_HTTP_JSON" "$APP_HTTP_PORT" "$APP_HTTP_PORTSTR"
bridgeports "APP_TRANSPORT_JSON" "$APP_TRANSPORT_PORT" "$APP_TRANSPORT_PORTSTR"

haproxylabel "APP_HA_PROXY" "${APP_HTTP_PORTSTR}~${APP_TRANSPORT_PORTSTR}"


bridgeports "APP_PORT_JSON" "27017" "$APP_PORTSTR"
haproxylabel "APP_HA_PROXY" "${APP_PORTSTR}"


APP_MAR_DIR="${APP_HOME}/marathon_files"
APP_MAR_FILE="DIRECTORY"
APP_DATA_DIR="$APP_HOME/data"
APP_CONF_DIR="$APP_HOME/conf"
APP_CONF_SCRIPTS_DIR="$APP_CONF_DIR/scripts"
APP_ENV_FILE="$CLUSTERMOUNT/zeta/kstore/env/env_${APP_ROLE}/${APP_NAME}_${APP_ID}.sh"


mkdir -p $APP_DATA_DIR
mkdir -p $APP_CONF_DIR
mkdir -p $APP_CONF_SCRIPTS_DIR
mkdir -p $APP_MAR_DIR

sudo chown -R ${APP_USER}:${IUSER} $APP_DATA_DIR
sudo chown -R ${APP_USER}:${IUSER} $APP_CONF_DIR
sudo chown -R ${APP_USER}:${IUSER} $APP_CONF_SCRIPTS_DIR

sudo chmod 770 $APP_DATA_DIR
sudo chmod 770 $APP_CONF_DIR
sudo chmod 770 $APP_CONF_SCRIPTS_DIR



cat > $APP_ENV_FILE << EOL1
#!/bin/bash
export ZETA_${APP_NAME}_${APP_ID}_CLUSTERNAME="${APP_CLUSTER_NAME}"
export ZETA_${APP_NAME}_${APP_ID}_HTTP_PORT="${APP_HTTP_PORT}"
export ZETA_${APP_NAME}_${APP_ID}_TRANSPORT_PORT="${APP_TRANSPORT_PORT}"
EOL1

APP_ZEN=""
for NODEID in $(seq $APP_CNT); do
    if [ "$APP_ZEN" == "" ]; then
        APP_ZEN="esnode${NODEID}-${APP_ID}-${APP_ROLE}.marathon.slave.mesos"
    else
        APP_ZEN="${APP_ZEN},esnode${NODEID}-${APP_ID}-${APP_ROLE}.marathon.slave.mesos"
    fi
done

cat > ${APP_CONF_DIR}/elasticsearch.yml << EOL5
cluster.name: "$APP_CLUSTER_NAME"
network.host: 0.0.0.0
discovery.zen.ping.unicast.hosts: "${APP_ZEN}"
http.port: $APP_HTTP_PORT
transport.tcp.port: $APP_TRANSPORT_PORT
network.publish_host: \${LIBPROCESS_IP}
$APP_SWAP_CONF
EOL5

cat  > ${APP_CONF_DIR}/logging.yml << EOL2
rootLogger: INFO,console
appender:
  console:
    type: console
    layout:
      type: consolePattern
      conversionPattern: "[%d{ISO8601}][%-5p][%-25c] %m%n"
EOL2




for NODEID in $(seq $APP_CNT); do
    echo "Creating Marathon file and directories for for node: $NODEID"

        NODE="node${NODEID}"
        VOL="${APP_DIR}.${APP_ROLE}.${APP_ID}.${NODE}"

        MNT="/${APP_DIR}/${APP_ROLE}/${APP_NAME}/${APP_ID}/data/${NODE}"
        NFSLOC="${APP_HOME}/data/${NODE}/"

        fs_mkvol "RETCODE" "$MNT" "$VOL" "770"
        sudo chown -R ${APP_USER}:${IUSER} $NFSLOC




cat > $APP_MAR_DIR/ESNODE${NODEID}.json << EOL
{
  "id": "${APP_MAR_ID}/esnode${NODEID}",
  "cmd": "chown -R ${APP_USER}:${IUSER} /usr/share/elasticsearch && sleep 10 && su -c /usr/share/elasticsearch/bin/elasticsearch $APP_USER",
  "cpus": ${APP_CPU},
  "mem": ${APP_MEM},
  "instances": 1,
  "labels": {
   $APP_HA_PROXY
   "CONTAINERIZER":"Docker"
  },
  "env": {
    "ZETA_ES_NODEID": "$NODE",
    "ES_HEAP_SIZE": "$APP_ES_HEAP"
  },
  "constraints": [["hostname", "UNIQUE"]],
  "ports": [],
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${APP_IMG}",
      "network": "BRIDGE",
$APP_PARAM
      "portMappings": [
        $APP_HTTP_JSON,
        $APP_TRANSPORT_JSON
      ]
    },
    "volumes": [
      { "containerPath": "/usr/share/elasticsearch/config", "hostPath": "${APP_CONF_DIR}", "mode": "RW" },
      { "containerPath": "/usr/share/elasticsearch/data/", "hostPath": "${APP_DATA_DIR}/${NODE}", "mode": "RW" }
    ]

  }
}
EOL
done



##########
# Provide instructions for next steps
echo ""
echo ""
echo "$APP_NAME instance ${APP_ID} installed at ${APP_HOME} and ready to go"
echo "To start please run: "
echo ""
echo "$ ./zeta package start ${APP_HOME}/$APP_ID.conf"
echo ""



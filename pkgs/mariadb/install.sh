#!/bin/bash


###############
# $APP Specific
echo "The next step will walk through instance defaults for ${APP_ID}"
echo ""

SOME_COMMENTS="Port for MariaDB"
PORTSTR="CLUSTER:tcp:30306:${APP_ROLE}:${APP_ID}:$SOME_COMMENTS"
getport "CHKADD" "$SOME_COMMENTS" "$SERVICES_CONF" "$PORTSTR"

if [ "$CHKADD" != "" ]; then
    getpstr "MYTYPE" "MYPROTOCOL" "APP_PORT" "MYROLE" "MYAPP_ID" "MYCOMMENTS" "$CHKADD"
    APP_PORTSTR="$CHKADD"
else
    @go.log FATAL "Failed to get Port for $APP_NAME $PSTR"
fi

bridgeports "APP_PORT_JSON" "3306" "$APP_PORTSTR"
haproxylabel "APP_HA_PROXY" "${APP_PORTSTR}"

read -e -p "Please enter the CPU shares to use with $APP_NAME: " -i "1.0" APP_CPU
echo ""
read -e -p "Please enter the Marathon Memory limit to use with $APP_NAME: " -i "2048" APP_MEM
echo ""


APP_MAR_FILE="${APP_HOME}/marathon.json"
APP_DATA_DIR="$APP_HOME/data"
APP_LOCK_DIR="$APP_HOME/lock"
APP_CRED_DIR="$APP_HOME/creds"
APP_LOG_DIR="$APP_HOME/logs"
APP_ENV_FILE="$CLUSTERMOUNT/zeta/kstore/env/env_${APP_ROLE}/${APP_NAME}_${APP_ID}.sh"

mkdir -p $APP_DATA_DIR
mkdir -p $APP_LOCK_DIR
mkdir -p $APP_CRED_DIR
mkdir -p $APP_LOG_DIR

sudo chown -R ${IUSER}:zeta${APP_ROLE}apps $APP_CRED_DIR
sudo chmod 770 $APP_CRED_DIR

sudo chown -R ${IUSER}:zeta${APP_ROLE}apps $APP_LOCK_DIR
sudo chmod 770 $APP_LOCK_DIR

sudo chown -R ${IUSER}:zeta${APP_ROLE}apps $APP_LOG_DIR
sudo chmod 770 $APP_LOG_DIR

cat > $APP_ENV_FILE << EOL1
#!/bin/bash
export ZETA_${APP_NAME}_${APP_ID}_PORT="${APP_PORT}"
EOL1

cat > $APP_MAR_FILE << EOL
{
  "id": "${APP_MAR_ID}",
  "cpus": $APP_CPU,
  "mem": $APP_MEM,
  "instances": 1,
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
        "containerPath": "/var/lib/mysql",
        "hostPath": "${APP_DATA_DIR}",
        "mode": "RW"
      },
      {
        "containerPath": "/lock",
        "hostPath": "${APP_LOCK_DIR}",
        "mode": "RW"
      },
      {
        "containerPath": "/creds",
        "hostPath": "${APP_CRED_DIR}",
        "mode": "RW"
      },
      {
        "containerPath": "/logs",
        "hostPath": "${APP_LOG_DIR}",
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

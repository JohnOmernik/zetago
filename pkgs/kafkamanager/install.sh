#!/bin/bash

###############
# $APP Specific
echo "The next step will walk through instance defaults for ${APP_ID}"
echo ""
echo ""


SOME_COMMENTS="Port for kafka-manager http"
PORTSTR="CLUSTER:tcp:26666:${APP_ROLE}:${APP_ID}:$SOME_COMMENTS"
getport "CHKADD" "$SOME_COMMENTS" "$SERVICES_CONF" "$PORTSTR"

if [ "$CHKADD" != "" ]; then
    getpstr "MYTYPE" "MYPROTOCOL" "APP_PORT" "MYROLE" "MYAPP_ID" "MYCOMMENTS" "$CHKADD"
    APP_PORTSTR="$CHKADD"
else
    @go.log FATAL "Failed to get Port for $APP_NAME $PSTR"
fi

bridgeports "APP_PORT_JSON" "9000" "$APP_PORTSTR"
haproxylabel "APP_HA_PROXY" "${APP_PORTSTR}"

echo ""
read -e -p "Please enter the CPU shares to use with $APP_NAME: " -i "1.0" APP_CPU
echo ""
read -e -p "Please enter the Marathon Memory limit to use with $APP_NAME: " -i "512" APP_MEM
echo ""
echo "Setting this to use 1 instance"

APP_CNT="1"

APP_MAR_FILE="${APP_HOME}/marathon.json"
APP_ENV_FILE="/mapr/$CLUSTERNAME/zeta/kstore/env/env_${APP_ROLE}/${APP_NAME}_${APP_ID}.sh"


cat > $APP_ENV_FILE << EOL1
#!/bin/bash
export ZETA_${APP_NAME}_${APP_ID}_PORT="${APP_PORT}"
EOL1

cat > $APP_MAR_FILE << EOL
{
  "id": "${APP_MAR_ID}",
  "cpus": ${APP_CPU},
  "mem": ${APP_MEM},
  "cmd": "cd $APP_VER_DIR && bin/kafka-manager",
  "instances": $APP_CNT,
  "labels": {
   ${APP_HA_PROXY}
   "CONTAINERIZER":"Docker"
  },
  "env": {
    "ZK_HOSTS": "$ZETA_ZKS"
  },
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${APP_IMG}",
      "network": "BRIDGE",
      "portMappings": [
        $APP_PORT_JSON
      ]
    }
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



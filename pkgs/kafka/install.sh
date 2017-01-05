#!/bin/bash


###############
# $APP Specific
echo "The next step will walk through instance defaults for ${APP_ID}"
echo ""
read -e -p "Please enter a port to use with kafka-mesos: " -i "21000" APP_PORT
echo ""
read -e -p "Please enter the CPU shares to use with the kafka-mesos scheduler: " -i "1.0" APP_CPU
echo ""
read -e -p "Please enter the Marathon Memory limit to use with kafka-mesos scheduler: " -i "768" APP_MEM
echo ""



APP_MAR_FILE="${APP_HOME}/marathon.json"
APP_ENV_FILE="/mapr/$CLUSTERNAME/zeta/kstore/env/env_${APP_ROLE}/${APP_NAME}_${APP_ID}.sh"





cat > $APP_ENV_FILE << EOL1
#!/bin/bash
export ZETA_${APP_NAME}_${APP_ID}_PORT="${APP_PORT}"
EOL1

cat > $APP_MAR_FILE << EOL
{
  "id": "${APP_MAR_ID}",
  "instances": 1,
  "cpus": ${APP_CPU},
  "mem": ${APP_MEM},
  "cmd": "export PATH=\`pwd\`/jre/bin:\$PATH && cd kafka-mesos && ./kafka-mesos.sh scheduler kafka-mesos.properties",
  "user": "${APP_USER}",
  "labels": {
   "CONTAINERIZER":"Mesos"
  },
  "env": {
    "JAVA_LIBRARY_PATH": "/opt/mesosphere/lib",
    "MESOS_NATIVE_JAVA_LIBRARY": "/opt/mesosphere/lib/libmesos.so",
    "LD_LIBRARY_PATH": "/opt/mesosphere/lib",
    "JAVA_HOME": "jre"
  },
  "uris": ["file://${APP_HOME}/${APP_TGZ}", "file://${APP_HOME}/kafka-mesos/${JAVA_TGZ}"]
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



#!/bin/bash


###############
# $APP Specific
echo "The next step will walk through instance defaults for ${APP_ID}"
echo ""
echo "You need a port to run MariaDB on"
echo ""
read -e -p "Please enter a port to use with mariadb: " -i "30306" APP_PORT
echo ""
read -e -p "Please enter the CPU shares to use with $APP_NAME: " -i "1.0" APP_CPU
echo ""
read -e -p "Please enter the Marathon Memory limit to use with $APP_NAME: " -i "2048" APP_MEM
echo ""


APP_MAR_FILE="${APP_HOME}/marathon.json"
APP_DATA_DIR="$APP_HOME/data"
APP_LOCK_DIR="$APP_HOME/lock"
APP_CRED_DIR="$APP_HOME/creds"
APP_ENV_FILE="/mapr/$CLUSTERNAME/zeta/kstore/env/env_${APP_ROLE}/${APP_NAME}_${APP_ID}.sh"

mkdir -p $APP_DATA_DIR
mkdir -p $APP_LOCK_DIR
mkdir -p $APP_CRED_DIR

sudo chown -R ${IUSER}:zeta${APP_ROLE}apps $APP_CRED_DIR
sudo chmod 770 $APP_CRED_DIR



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
   "CONTAINERIZER":"Docker"
  },
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${APP_IMG}",
      "network": "BRIDGE",
      "portMappings": [
        { "containerPort": 3306, "hostPort": ${APP_PORT}, "servicePort": 0, "protocol": "tcp"}
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



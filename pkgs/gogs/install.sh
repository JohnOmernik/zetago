#!/bin/bash

###############
# $APP Specific
echo "The next step will walk through instance defaults for ${APP_ID}"
echo ""
echo "The Gogs git server needs two ports, a SSH port and a HTTPS port"
echo ""
read -e -p "Please enter a ssh port to use with gogs: " -i "30022" APP_SSH_PORT
echo ""
read -e -p "Please enter a https port to use with gogs: " -i "30443" APP_HTTPS_PORT
echo ""
read -e -p "Please enter the CPU shares to use with $APP_NAME: " -i "1.0" APP_CPU
echo ""
read -e -p "Please enter the Marathon Memory limit to use with $APP_NAME: " -i "2048" APP_MEM
echo ""
echo "Please now enter a gogs secret to use in the config"
getpass "gogssecret" APP_PASS


APP_MAR_FILE="${APP_HOME}/marathon.json"
APP_DATA_DIR="${APP_HOME}/data"
APP_CONF_DIR="${APP_DATA_DIR}/gogs/conf"
APP_CERT_LOC="${APP_HOME}/certs"
APP_ENV_FILE="/mapr/$CLUSTERNAME/zeta/kstore/env/env_${APP_ROLE}/${APP_NAME}_${APP_ID}.sh"

mkdir -p $APP_DATA_DIR
mkdir -p ${APP_CERT_LOC}
mkdir -p ${APP_CONF_DIR}

sudo chmod -R 770 ${APP_CERT_LOC}

cat > ${APP_CONF_DIR}/app.ini << EO6
APP_NAME = Gogs: Go Git Service
RUN_USER = git
RUN_MODE = prod

[database]
DB_TYPE  = sqlite3
HOST     = 127.0.0.1:3306
NAME     = gogs
USER     = root
PASSWD   = toor
SSL_MODE = disable
PATH     = data/gogs.db

[repository]
ROOT = /data/git/gogs-repositories

[server]
PROTOCOL     = https
DOMAIN       = ${APP_ID}-${APP_ROLE}.${ZETA_MARATHON_HOST}
HTTP_PORT    = ${APP_HTTPS_PORT}
ROOT_URL     = https://${APP_ID}-${APP_ROLE}.${ZETA_MARATHON_HOST}:${APP_HTTPS_PORT}
DISABLE_SSH  = false
SSH_PORT     = 22
OFFLINE_MODE = false
CERT_FILE    = /certs/cert.pem
KEY_FILE     = /certs/key-no-password.pem

[mailer]
ENABLED = false

[service]
REGISTER_EMAIL_CONFIRM = false
ENABLE_NOTIFY_MAIL     = false
DISABLE_REGISTRATION   = false
ENABLE_CAPTCHA         = true
REQUIRE_SIGNIN_VIEW    = false

[picture]
DISABLE_GRAVATAR        = false
ENABLE_FEDERATED_AVATAR = false

[session]
PROVIDER = file

[log]
MODE      = file
LEVEL     = Info
ROOT_PATH = /data/gogs/log

[security]
INSTALL_LOCK = true
SECRET_KEY   = $APP_PASS

EO6



cat > $APP_ENV_FILE << EOL1
#!/bin/bash
export ZETA_${APP_NAME}_${APP_ID}_PORT="${APP_PORT}"
EOL1

CN_GUESS="${APP_ID}-${APP_ROLE}.marathon.slave.mesos"

. /mapr/$CLUSTERNAME/zeta/shared/zetaca/gen_server_cert.sh

cat > $APP_MAR_FILE << EOL
{
  "id": "${APP_MAR_ID}",
  "cpus": ${APP_CPU},
  "mem": ${APP_MEM},
  "instances": 1,
  "labels": {
   "CONTAINERIZER":"Docker"
  },
  "ports": [],
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${APP_IMG}",
      "network": "BRIDGE",
      "portMappings": [
        { "containerPort": 22, "hostPort": ${APP_SSH_PORT}, "servicePort": 0, "protocol": "tcp"},
        { "containerPort": ${APP_HTTPS_PORT}, "hostPort": ${APP_HTTPS_PORT}, "servicePort": 0, "protocol": "tcp"}
      ]
    },
    "volumes": [
      { "containerPath": "/data", "hostPath": "${APP_DATA_DIR}", "mode": "RW" },
      { "containerPath": "/certs", "hostPath": "${APP_CERT_LOC}", "mode": "RO" }
    ]

  }
}
EOL

echo ""
echo ""
echo "Instance created at ${APP_HOME}"
echo ""
echo "To start run ${APP_HOME}/start_instance.sh"
echo ""
echo ""





##########
# Provide instructions for next steps
echo ""
echo ""
echo "$APP_NAME instance ${APP_ID} installed at ${APP_HOME} and ready to go"
echo "To start please run: "
echo ""
echo "$ ./zeta package start ${APP_HOME}/$APP_ID.conf"
echo ""



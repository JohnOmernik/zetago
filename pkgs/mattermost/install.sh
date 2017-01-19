#!/bin/bash

###############
# $APP Specific
echo "The next step will walk through instance defaults for ${APP_ID}"
echo ""
echo ""
echo "Information related to the Mattermost DB Server:"
echo ""

SOME_COMMENTS="Postgres port for Mattermost"
PORTSTR="CLUSTER:tcp:30480:${APP_ROLE}:${APP_ID}:$SOME_COMMENTS"
getport "CHKADD" "$SOME_COMMENTS" "$SERVICES_CONF" "$PORTSTR"

if [ "$CHKADD" != "" ]; then
    getpstr "MYTYPE" "MYPROTOCOL" "APP_DB_PORT" "MYROLE" "MYAPP_ID" "MYCOMMENTS" "$CHKADD"
    APP_DB_PORTSTR="$CHKADD"
else
    @go.log FATAL "Failed to get Port for $APP_NAME $PSTR"
fi

bridgeports "APP_DB_PORT_JSON", "5432", "$APP_DB_PORTSTR"


echo ""
read -e -p "Please enter the amount of CPU to limit the Postgres instance for MM to: " -i "2.0" APP_DB_CPU
echo ""
read -e -p "Please enter the amount of Memory to limit the Postgres instance for MM to: " -i "4096" APP_DB_MEM
echo ""
read -e -p "Please enter the amount of Shared Buffer Memory: " -i "2048MB" APP_MEM
echo ""
read -e -p "Please enter a username for the DB user for Mattermost: " -i "mmuser" APP_DB_USER
echo ""
echo ""
echo "Please now enter the password for the DB user $APP_DB_USER"
echo ""
getpass "$APP_DB_USER" APP_DB_PASS
echo ""
echo "Information related to Application Server:"
echo ""

SOME_COMMENTS="Application port for Mattermost"
PORTSTR="CLUSTER:tcp:30481:${APP_ROLE}:${APP_ID}:$SOME_COMMENTS"
getport "CHKADD" "$SOME_COMMENTS" "$SERVICES_CONF" "$PORTSTR"

if [ "$CHKADD" != "" ]; then
    getpstr "MYTYPE" "MYPROTOCOL" "APP_APP_PORT" "MYROLE" "MYAPP_ID" "MYCOMMENTS" "$CHKADD"
    APP_APP_PORTSTR="$CHKADD"
else
    @go.log FATAL "Failed to get Port for $APP_NAME $PSTR"
fi

bridgeports "APP_APP_PORT_JSON", "80", "$APP_APP_PORTSTR"




read -e -p "Please enter the amount of CPU to limit the MM app server: " -i "2.0" APP_APP_CPU
echo ""
read -e -p "Please enter the amount of Memory to limit the MM app server: " -i "2048" APP_APP_MEM
echo ""
echo "Information related to Web Server:"
echo ""

SOME_COMMENTS="HTTPS port for Mattermost"
PORTSTR="CLUSTER:tcp:30483:${APP_ROLE}:${APP_ID}:$SOME_COMMENTS"
getport "CHKADD" "$SOME_COMMENTS" "$SERVICES_CONF" "$PORTSTR"

if [ "$CHKADD" != "" ]; then
    getpstr "MYTYPE" "MYPROTOCOL" "APP_HTTPS_PORT" "MYROLE" "MYAPP_ID" "MYCOMMENTS" "$CHKADD"
    APP_HTTPS_PORTSTR="$CHKADD"
else
    @go.log FATAL "Failed to get Port for $APP_NAME $PSTR"
fi

bridgeports "APP_HTTPS_PORT_JSON", "443", "$APP_HTTPS_PORTSTR"



read -e -p "Please enter the amount of CPU to limit the MM web server: " -i "2.0" APP_WEB_CPU
echo ""
read -e -p "Please enter the amount of Memory to limit the MM web server: " -i "2048" APP_WEB_MEM
echo ""
echo "Using direct IPs for networking"
APP_DOMAIN_ROOT="marathon.slave.mesos"


haproxylabel "APP_DB_HA_PROXY" "${APP_DB_PORTSTR}"
haproxylabel "APP_APP_HA_PROXY" "${APP_APP_PORTSTR}"
haproxylabel "APP_HTTPS_HA_PROXY" "${APP_HTTPS_PORTSTR}"


APP_MAR_APP_FILE="${APP_HOME}/marathon_app.json"
APP_MAR_DB_FILE="${APP_HOME}/marathon_db.json"
APP_MAR_WEB_FILE="${APP_HOME}/marathon_web.json"

APP_MAR_APP_ID="${APP_ROLE}/${APP_ID}/mattermostapp"
APP_MAR_DB_ID="${APP_ROLE}/${APP_ID}/mattermostdb"
APP_MAR_WEB_ID="${APP_ROLE}/${APP_ID}/mattermostweb"

APP_ENV_FILE="/mapr/$CLUSTERNAME/zeta/kstore/env/env_${APP_ROLE}/${APP_NAME}_${APP_ID}.sh"
APP_CERT_LOC="${APP_HOME}/certs"

mkdir -p ${APP_HOME}/db_data
mkdir -p ${APP_HOME}/db_init
mkdir -p ${APP_HOME}/app_config
mkdir -p ${APP_HOME}/app_data
mkdir -p ${APP_CERT_LOC}
sudo chmod 770 ${APP_HOME}/db_init
sudo chmod 770 ${APP_HOME}/app_config
sudo chmod 770 ${APP_CERT_LOC}



CN_GUESS="mattermostweb-${APP_ID}-${APP_ROLE}.${APP_DOMAIN_ROOT}"
. /mapr/$CLUSTERNAME/zeta/shared/zetaca/gen_server_cert.sh

cat > ${APP_CERT_LOC}/run.sh << EOR
#!/bin/bash
sed -i "s@http://app@http://\${APP_HOST}@" /etc/nginx/sites-available/mattermost
sed -i "s@http://app@http://\${APP_HOST}@" /etc/nginx/sites-available/mattermost-ssl
/docker-entry.sh
EOR
chmod +x ${APP_CERT_LOC}/run.sh


cat > $APP_ENV_FILE << EOL1
#!/bin/bash
export ZETA_${APP_NAME}_${APP_ID}_PORT="${APP_HTTPS_PORT}"
EOL1

cat > ${APP_HOME}/app_config/run.sh << EOQ
#!/bin/bash

export MM_USERNAME="$APP_DB_USER"
export MM_PASSWORD="$APP_DB_PASS"
echo "Starting Docker Entry Point"
/docker-entry.sh
EOQ
chmod +x ${APP_HOME}/app_config/run.sh


cat > ${APP_HOME}/db_init/run.sh << EOI
#!/bin/bash

export MM_USERNAME="$APP_DB_USER"
export MM_PASSWORD="$APP_DB_PASS"
echo "Starting Docker Entry Point"
CONF="/var/lib/postgresql/data/postgresql.conf"
if [ -f "\$CONF" ]; then
    echo "Updating Conf and setting shared buffers to $APP_MEM"
    sed -i -e "s/^shared_buffers =.*\$/shared_buffers = ${APP_MEM}/" \$CONF
else
    echo "Bootstrapped, no conf, restart to update conf"
fi
/docker-entrypoint1.sh postgres
EOI
chmod +x ${APP_HOME}/db_init/run.sh

cat > $APP_MAR_DB_FILE << EOD
{
  "id": "${APP_MAR_DB_ID}",
  "cmd": "/db_init/run.sh",
  "cpus": ${APP_DB_CPU},
  "mem": ${APP_DB_MEM},
  "instances": 1,
  "labels": {
    $APP_DB_HA_PROXY
   "CONTAINERIZER":"Docker"
  },
  "ports": [],
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${APP_IMG_DB}",
      "network": "BRIDGE",
      "portMappings": [
        ${APP_DB_PORT_JSON}
      ]
    },
    "volumes": [
      { "containerPath": "/db_init", "hostPath": "${APP_HOME}/db_init", "mode": "RO" },
      { "containerPath": "/var/lib/postgresql/data", "hostPath": "${APP_HOME}/db_data", "mode": "RW" },
      { "containerPath": "/etc/localtime", "hostPath": "/etc/localtime", "mode": "RO" }
    ]

  }
}
EOD

cat > $APP_MAR_APP_FILE << EOA
{
  "id": "${APP_MAR_APP_ID}",
  "cmd": "/mattermost/config/run.sh",
  "cpus": ${APP_APP_CPU},
  "mem": ${APP_APP_MEM},
  "instances": 1,
  "labels": {
   $APP_APP_HA_PROXY
   "CONTAINERIZER":"Docker"
  },
  "env": {
    "DB_HOST": "mattermostdb-${APP_ID}-${APP_ROLE}.${APP_DOMAIN_ROOT}",
    "DB_PORT_5432_TCP_PORT": "${APP_DB_PORT}"
  },
  "ports": [],
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${APP_IMG_APP}",
      "network": "BRIDGE",
      "portMappings": [
        $APP_APP_PORT_JSON
      ]
    },
    "volumes": [
      { "containerPath": "/mattermost/config", "hostPath": "${APP_HOME}/app_config", "mode": "RW" },
      { "containerPath": "/mattermost/data", "hostPath": "${APP_HOME}/app_data", "mode": "RW" },
      { "containerPath": "/etc/localtime", "hostPath": "/etc/localtime", "mode": "RO" }
    ]

  }
}
EOA

cat > $APP_MAR_WEB_FILE << EOW
{
  "id": "${APP_MAR_WEB_ID}",
  "cmd": "/cert/run.sh",
  "cpus": ${APP_WEB_CPU},
  "mem": ${APP_WEB_MEM},
  "instances": 1,
  "labels": {
   $APP_HTTPS_HA_PROXY
   "CONTAINERIZER":"Docker"
  },
  "env": {
    "APP_HOST": "mattermostapp-${APP_ID}-${APP_ROLE}.${APP_DOMAIN_ROOT}",
    "PLATFORM_PORT_80_TCP_PORT": "${APP_APP_PORT}",
    "MATTERMOST_ENABLE_SSL": "true"
  },
  "ports": [],
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${APP_IMG_WEB}",
      "network": "BRIDGE",
      "portMappings": [
        ${APP_HTTPS_PORT_JSON}
      ]
    },
    "volumes": [
      { "containerPath": "/cert", "hostPath": "${APP_CERT_LOC}", "mode": "RO" },
      { "containerPath": "/etc/localtime", "hostPath": "/etc/localtime", "mode": "RO" }
    ]

  }
}
EOW


##########
# Provide instructions for next steps
echo ""
echo ""
echo "$APP_NAME instance ${APP_ID} installed at ${APP_HOME} and ready to go"
echo "To start please run: "
echo ""
echo "$ ./zeta package start ${APP_HOME}/$APP_ID.conf"
echo ""



#!/bin/bash

###############
# $APP Specific
echo ""
echo ""
echo ""
echo "While the previous questions will be used to create the directories for configs, the actual marathon ID of this lb will be based off the ES Cluster it is serving."
echo "We do this to help with grouping things together in Marathon"
echo ""
read -e -p "Please provide the path to the elastic search instance conf file you wish this insance to load balance: " -i "/path/to/instance.conf" APP_ES_CONF
echo ""
ES_HOME=$(cat $APP_ES_CONF|grep "APP_HOME"|cut -d"=" -f2|sed "s/\"//g")
ES_ID=$(cat $APP_ES_CONF|grep "APP_ID"|cut -d"=" -f2|sed "s/\"//g")
ES_ROLE=$(cat $APP_ES_CONF|grep "APP_ROLE"|cut -d"=" -f2|sed "s/\"//g")

ES_BASE="${ES_ID}-${ES_ROLE}.marathon.slave.mesos"
ES_PORT=$(cat $ES_HOME/conf/elasticsearch.yml|grep "http\.port"|cut -d":" -f2|sed "s/ //g")
ES_NUM_NODES=$(ls -1 $ES_HOME/marathon_files|wc -l)

ES_SERVERS=""
for X in $(seq $ES_NUM_NODES); do
    ES_SERVERS="${ES_SERVERS}     server esnode${X}-${ES_BASE}:${ES_PORT};"$'\n'
done

if [ "$ES_ROLE" != "$APP_ROLE" ]; then
    @go.log FATAL "Role of es proxy ($APP_ROLE) much match the role of the ES Instance the proxy is serving ($ES_ROLE) - Exiting"
fi

echo "The Marathon ID, which was set to be $APP_ROLE/$APP_ID will now be changed to: ${APP_ROLE}/${ES_ID}/${APP_ID}"

APP_MAR_ID="$APP_ROLE/$ES_ID/${APP_ID}"


echo "The next step will walk through instance defaults for ${APP_ID}"
echo ""
read -e -p "Please enter the CPU shares to use with $APP_NAME: " -i "1.0" APP_CPU
echo ""
read -e -p "Please enter the Marathon Memory limit to use with $APP_NAME: " -i "1024" APP_MEM
echo ""

PORTSTR="CLUSTER:tcp:30200:${APP_ROLE}:${APP_ID}:Port for $APP_NAME $APP_ID"
getport "CHKADD" "Port for $APP_NAME $APP_ID" "$SERVICES_CONF" "$PORTSTR"

if [ "$CHKADD" != "" ]; then
    getpstr "MYTYPE" "MYPROTOCOL" "APP_PORT" "MYROLE" "MYAPP_ID" "MYCOMMENTS" "$CHKADD"
    APP_PORTSTR="$CHKADD"
else
    @go.log FATAL "Failed to get Port for $APP_NAME instance $APP_ID with $PSTR"
fi

APP_CONT_PORT="443"

bridgeports "APP_PORT_JSON" "$APP_CONT_PORT" "$APP_PORTSTR"
haproxylabel "APP_HA_PROXY" "${APP_PORTSTR}"
portslist "APP_PORT_LIST" "${APP_PORTSTR}"

APP_MAR_FILE="${APP_HOME}/marathon.json"
APP_CERT_LOC="$APP_HOME/certs"
APP_LOG_DIR="$APP_HOME/logs"
APP_CONF_DIR="$APP_HOME/conf"

APP_ENV_FILE="$CLUSTERMOUNT/zeta/kstore/env/env_${APP_ROLE}/${APP_NAME}_${APP_ID}.sh"


mkdir -p $APP_LOG_DIR
mkdir -p $APP_CONF_DIR
mkdir -p $APP_CERT_LOC
sudo chmod 770 $APP_LOG_DIR
sudo chmod 770 $APP_CONF_DIR
sudo chmod 770 $APP_CERT_LOC

CN_GUESS="${APP_ID}-${ES_ID}-${APP_ROLE}.marathon.slave.mesos"

. $CLUSTERMOUNT/zeta/shared/zetaca/gen_server_cert.sh

cat > $APP_ENV_FILE << EOL1
#!/bin/bash
export ZETA_${APP_NAME}_${APP_ID}_PORT="${APP_PORT}"
EOL1

cat > ${APP_CONF_DIR}/default.conf << EOL5
    ssl_session_cache   shared:SSL:10m;
    ssl_session_timeout 10m;

    upstream elasticsearch_servers {
        zone elasticsearch_servers 64K;
   $ES_SERVERS
    }

    server {
        listen              443 ssl;
        server_name         $CN_GUESS;
        keepalive_timeout   70;

        ssl_certificate     /etc/nginx/certs/cert.pem;
        ssl_certificate_key /etc/nginx/certs/key-no-password.pem;
        ssl_protocols       TLSv1 TLSv1.1 TLSv1.2;
        ssl_ciphers         HIGH:!aNULL:!MD5;

      location / {
        proxy_pass http://elasticsearch_servers;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_connect_timeout 5s;
        proxy_read_timeout 10s;
    }

    # redirect server error pages to the static page /50x.html
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
    access_log /var/log/nginx/es_access.log combined;


    }
EOL5

cat > $APP_MAR_FILE << EOL
{
  "id": "${APP_MAR_ID}",
  "cpus": ${APP_CPU},
  "mem": ${APP_MEM},
  "instances": 1,
  "labels": {
   $APP_HA_PROXY
   "CONTAINERIZER":"Docker"
  },
  $APP_PORT_LIST
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
      { "containerPath": "/etc/nginx/conf.d", "hostPath": "${APP_CONF_DIR}", "mode": "RW" },
      { "containerPath": "/var/log/nginx", "hostPath": "${APP_LOG_DIR}", "mode": "RW" },
      { "containerPath": "/etc/nginx/certs", "hostPath": "${APP_CERT_LOC}", "mode": "RO" }
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



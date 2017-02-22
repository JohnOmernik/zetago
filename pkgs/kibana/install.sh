#!/bin/bash

###############
# $APP Specific
echo "The next step will walk through instance defaults for ${APP_ID}"
echo ""
read -e -p "Please enter the CPU shares to use with $APP_NAME: " -i "1.0" APP_CPU
echo ""
read -e -p "Please enter the Marathon Memory limit to use with $APP_NAME: " -i "1024" APP_MEM
echo ""
read -e -p "Please provide an Elastic Search HTTP URL to use for this instance of $APP_NAME: " APP_ES_URL
echo ""
read -e -p "What user should we run $APP_NAME as: " -i "zetasvc${APP_ROLE}" APP_USER

PORTSTR="CLUSTER:tcp:30560:${APP_ROLE}:${APP_ID}:Port for $APP_NAME $APP_ID"
getport "CHKADD" "Port for $APP_NAME $APP_ID" "$SERVICES_CONF" "$PORTSTR"

if [ "$CHKADD" != "" ]; then
    getpstr "MYTYPE" "MYPROTOCOL" "APP_PORT" "MYROLE" "MYAPP_ID" "MYCOMMENTS" "$CHKADD"
    APP_PORTSTR="$CHKADD"
else
    @go.log FATAL "Failed to get Port for $APP_NAME instance $APP_ID with $PSTR"
fi

APP_CONT_PORT="5601"

bridgeports "APP_PORT_JSON" "$APP_CONT_PORT" "$APP_PORTSTR"
haproxylabel "APP_HA_PROXY" "${APP_PORTSTR}"
portslist "APP_PORT_LIST" "${APP_PORTSTR}"

APP_MAR_FILE="${APP_HOME}/marathon.json"
APP_CERT_LOC="$APP_HOME/certs"
APP_DATA_DIR="$APP_HOME/data"
APP_CONF_DIR="$APP_HOME/conf"

APP_ENV_FILE="$CLUSTERMOUNT/zeta/kstore/env/env_${APP_ROLE}/${APP_NAME}_${APP_ID}.sh"


mkdir -p $APP_DATA_DIR
mkdir -p $APP_CONF_DIR
mkdir -p $APP_CERT_LOC
sudo chmod 770 $APP_DATA_DIR
sudo chmod 770 $APP_CONF_DIR
sudo chmod 770 $APP_CERT_LOC

CN_GUESS="${APP_ID}-${APP_ROLE}.marathon.slave.mesos"

. $CLUSTERMOUNT/zeta/shared/zetaca/gen_server_cert.sh

cat > $APP_ENV_FILE << EOL1
#!/bin/bash
export ZETA_${APP_NAME}_${APP_ID}_PORT="${APP_PORT}"
EOL1

cat > ${APP_CONF_DIR}/kibana.yml << EOL5
# Kibana is served by a back end server. This controls which port to use.
server.port: $APP_CONT_PORT

# The host to bind the server to.
# server.host: "0.0.0.0"

# If you are running kibana behind a proxy, and want to mount it at a path,
# specify that path here. The basePath can't end in a slash.
# server.basePath: ""

# The maximum payload size in bytes on incoming server requests.
# server.maxPayloadBytes: 1048576

# The Elasticsearch instance to use for all your queries.
elasticsearch.url: "$APP_ES_URL"

# preserve_elasticsearch_host true will send the hostname specified in 'elasticsearch'. If you set it to false,
# then the host you use to connect to *this* Kibana instance will be sent.
# elasticsearch.preserveHost: true

# Kibana uses an index in Elasticsearch to store saved searches, visualizations
# and dashboards. It will create a new index if it doesn't already exist.
kibana.index: ".kibana"

# The default application to load.
# kibana.defaultAppId: "discover"

# If your Elasticsearch is protected with basic auth, these are the user credentials
# used by the Kibana server to perform maintenance on the kibana_index at startup. Your Kibana
# users will still need to authenticate with Elasticsearch (which is proxied through
# the Kibana server)
# elasticsearch.username: "user"
# elasticsearch.password: "pass"

# SSL for outgoing requests from the Kibana Server to the browser (PEM formatted)
server.ssl.cert: /opt/kibana/certs/cert.pem
server.ssl.key: /opt/kibana/certs/key-no-password.pem

# Optional setting to validate that your Elasticsearch backend uses the same key files (PEM formatted)
# elasticsearch.ssl.cert: /path/to/your/client.crt
# elasticsearch.ssl.key: /path/to/your/client.key

# If you need to provide a CA certificate for your Elasticsearch instance, put
# the path of the pem file here.
elasticsearch.ssl.ca: /opt/kibana/certs/cacert.pem

# Set to false to have a complete disregard for the validity of the SSL
# certificate.
elasticsearch.ssl.verify: true

# Time in milliseconds to wait for elasticsearch to respond to pings, defaults to
# request_timeout setting
# elasticsearch.pingTimeout: 1500

# Time in milliseconds to wait for responses from the back end or elasticsearch.
# This must be > 0
# elasticsearch.requestTimeout: 30000

# Header names and values that are sent to Elasticsearch. Any custom headers cannot be overwritten
# by client-side headers.
# elasticsearch.customHeaders: {}

# Time in milliseconds for Elasticsearch to wait for responses from shards.
# Set to 0 to disable.
# elasticsearch.shardTimeout: 0

# Time in milliseconds to wait for Elasticsearch at Kibana startup before retrying
# elasticsearch.startupTimeout: 5000

# Set the path to where you would like the process id file to be created.
# pid.file: /var/run/kibana.pid

# If you would like to send the log output to a file you can set the path below.
# logging.dest: stdout

# Set this to true to suppress all logging output.
# logging.silent: false

# Set this to true to suppress all logging output except for error messages.
# logging.quiet: false

# Set this to true to log all events, including system usage information and all requests.
# logging.verbose: false
EOL5

cat > $APP_MAR_FILE << EOL
{
  "id": "${APP_MAR_ID}",
  "cmd": "chown -R ${APP_USER}:${IUSER} /opt/kibana && sleep 5 && su -c /opt/kibana/bin/kibana $APP_USER",
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
      { "containerPath": "/opt/kibana/config", "hostPath": "${APP_CONF_DIR}", "mode": "RW" },
      { "containerPath": "/opt/kibana/data", "hostPath": "${APP_DATA_DIR}", "mode": "RW" },
      { "containerPath": "/opt/kibana/certs", "hostPath": "${APP_CERT_LOC}", "mode": "RW" }
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



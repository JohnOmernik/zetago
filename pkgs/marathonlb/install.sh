#!/bin/bash

###############
# $APP Specific
echo "At this point the marathon-lb package can only be installed in the shared role with id marathonlb"
echo ""
echo "If you do not wish to do this, answer N here:"
read -e -p "Reset variables to shared for APP_ROLE and marathonlb for APP_ID? (Y/N): " -i "Y" RESETVAR

if [ "$RESETVAR" != "Y" ]; then
    @go.log FATAL "Cannot proceed at this time with Marathon LB install - Exiting"
fi

sudo rm -rf $APP_HOME

APP_NAME="marathonlb"
APP_ROLE="shared"
APP_DIR="zeta"
APP_ID="marathonlb"
APP_ROOT="/mapr/${CLUSTERNAME}/${APP_DIR}/shared/${APP_NAME}"
APP_PKG_DIR="${APP_ROOT}/packages"
APP_HOME="/mapr/${CLUSTERNAME}/${APP_DIR}/${APP_ROLE}/${APP_NAME}/${APP_ID}"
APP_MAR_FILE="$APP_HOME/marathon.json"
APP_MAR_ID="shared/marathonlb"
APP_CERT_LOC="${APP_HOME}/certs"
APP_TEMPLATES="${APP_HOME}/templates"
APP_ENV_FILE="/mapr/$CLUSTERNAME/zeta/kstore/env/env_${APP_ROLE}/${APP_NAME}_${APP_ID}.sh"

if [ -d "$APP_HOME" ]; then
    @go.log FATAL "Marathon LB already appears insstalled at $APP_HOME - EXITING"
fi

mkdir -p $APP_HOME
mkdir -p $APP_CERT_LOC
mkdir -p ${APP_TEMPLATES}

sudo chmod -R 770 ${APP_CERT_LOC}


echo "Resources for $APP_NAME"
read -e -p "Please enter the amount of Memory for $APP_NAME: " -i "1024" APP_MEM
read -e -p "Please enter the amount of CPU shares for $APP_NAME: " -i "1.0" APP_CPU
echo ""
read -e -p "How many edge nodes will you be running with $APP_NAME? " -i "2" APP_CNT

echo ""
read -e -p "Do you wish to use the slave_public role? - Answering no will allows Marathon LB to run on any agent node, (you can still use constraints in the next question)  (Y/N): " -i "Y" USE_SLAVE_PUBLIC
if [ "$USE_SLAVE_PUBLIC" == "Y" ]; then
       APP_ACCEPTED_ROLES='"acceptedResourceRoles": ["slave_public"],'
else
       APP_ACCEPTED_ROLES='"acceptedResourceRoles": ["*"],'
fi

echo "Please provide a Mesos contraint to pin $APP_NAME to a specific number of hosts (likely $APP_CNT)"
echo "If you answered Y to the previous question, these constraints MUST be on nodes that are in the slave_public role or marathonlb won't start"
echo "For example, if you want to run it on two Mesos Agents with the host names 192.168.0.102 and 192.168.0.104 you could enter: 192.168.0.10[24]"
echo ""
read -e -p "Mesos Constraint: " APP_CONSTRAINT
if [ "$APP_CONSTRAINT" == "" ]; then
    APP_CONSTRAINT=""
else
    APP_CONSTRAINT="[\"hostname\", \"LIKE\", \"$APP_CONSTRAINT"\"], "
fi
echo "Do you with to generate certificates with ZetaCA or use external enterprise trusted certs (recommended)?"
read -e -p "Generate certificates from Zeta CA? " -i "N" ZETA_CA_CERTS
echo ""
if [ "$ZETA_CA_CERTS" == "Y" ]; then
    CN_GUESS="${APP_ID}-${APP_ROLE}.marathon.slave.mesos"
    . /mapr/$CLUSTERNAME/zeta/shared/zetaca/gen_server_cert.sh
else
    echo "Please enter the certificate file name:"
    read -e -p "Certificate file: " -i "cert.pem" CERT_FILE_NAME
    echo ""
    echo "Please ensure there is a certificate there in ${APP_CERT_LOC} named $CERT_FILE_NAME"
    echo ""
fi


cat > $APP_ENV_FILE << EOL1
#!/bin/bash
export ZETA_MARATHON_LB_INSTALLED="Y"
EOL1

cat > ${APP_MAR_FILE} << EOL
{
  "id": "${APP_MAR_ID}",
  "cpus": ${APP_CPU},
  "mem": ${APP_MEM},
  "instances": ${APP_CNT},
  "args":["sse", "--marathon", "http://${ZETA_MARATHON_URL}", "--group", "*"],
  "constraints": [${APP_CONSTRAINT}["hostname", "UNIQUE"]],
  "env": {
    "HAPROXY_SSL_CERT":"/marathonlb/certs/${CERT_FILE_NAME}"
  },
  "labels": {
    "PRODUCTION_READY":"True",
    "CONTAINERIZER":"Docker",
    "ZETAENV":"${APP_ROLE}"
  },
  "ports": [ 80,443,9090,9091 ],
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${APP_IMG}",
      "network": "HOST"
    },
   "volumes": [
      { "containerPath": "/marathonlb/templates", "hostPath": "${APP_TEMPLATES}", "mode": "RO" },
      { "containerPath": "/marathonlb/certs", "hostPath": "$APP_CERT_LOC", "mode": "RO" }

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



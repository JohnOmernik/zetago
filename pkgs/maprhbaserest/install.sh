#!/bin/bash

###############
# $APP Specific
echo "The next step will walk through instance defaults for ${APP_ID}"
echo ""
##########

PORTSTR="CLUSTER:tcp:27005:${APP_ROLE}:${APP_ID}:HBASEREST Info Port"
getport "CHKADD" "HBASEREST Info Port" "$SERVICES_CONF" "$PORTSTR"

if [ "$CHKADD" != "" ]; then
    getpstr "MYTYPE" "MYPROTOCOL" "APP_INFO_PORT" "MYROLE" "MYAPP_ID" "MYCOMMENTS" "$CHKADD"
    APP_INFO_PORTSTR="$CHKADD"
else
    @go.log FATAL "Failed to get Port for $APP_NAME instance $APP_ID with $PSTR"
fi

PORTSTR="CLUSTER:tcp:27000:${APP_ROLE}:${APP_ID}:HBASEREST HTTP Port"
getport "CHKADD" "HBASEREST HTTP Port" "$SERVICES_CONF" "$PORTSTR"

if [ "$CHKADD" != "" ]; then
    getpstr "MYTYPE" "MYPROTOCOL" "APP_PORT" "MYROLE" "MYAPP_ID" "MYCOMMENTS" "$CHKADD"
    APP_PORTSTR="$CHKADD"
else
    @go.log FATAL "Failed to get Port for $APP_NAME instance $APP_ID with $PSTR"
fi


bridgeports "APP_INFO_PORT_JSON" "8005" "$APP_INFO_PORTSTR"
bridgeports "APP_PORT_JSON" "8000" "$APP_PORTSTR"
haproxylabel "APP_HA_PROXY" "${APP_PORTSTR}~${APP_INFO_PORTSTR}"




read -e -p "Please enter the port for ${APP_NAME} info service: " -i "27005" APP_INFO_PORT
read -e -p "Please enter the port for ${APP_NAME} REST API: " -i "27000" APP_PORT
read -e -p "Please enter the amount of memory to use for the $APP_ID instance of $APP_NAME: " -i "1024" APP_MEM
read -e -p "Please enter the amount of cpu to use for the $APP_ID instance of $APP_NAME: " -i "1.0" APP_CPU

read -e -p "What username will this instance of hbaserest run as. Note: it must have access to the tables you wish provide via REST API: " -i "zetasvc${APP_ROLE}" APP_USER
echo ""
echo "The next prompt will ask you for the root location for hbase table namespace mapping"
echo "Due to how maprdb and hbase interace, you need to provide a MapR-FS directory, where, within, are the tables this hbase rest API will serve"
echo ""
echo "For example, if in the path: /data/prod/myhbasetables,  you have two tables, tab1 and tab2, you want served by this HBASE rest instance"
echo "Then at the prompt for directory root, pot in /data/prod/myhbasetables"
echo ""
echo "This can be changed in the conf directory (the hbase-site.xml) for this instance"

read -e -p "What root directory should we use to identify hbase tables? :" -i "/apps/${APP_ROLE}/myhbasetables" APP_TABLE_ROOT

APP_MAR_FILE="${APP_HOME}/marathon.json"
APP_ENV_FILE="$CLUSTERMOUNT/zeta/kstore/env/env_${APP_ROLE}/${APP_NAME}_${APP_ID}.sh"
APP_CONF_DIR="${APP_HOME}/conf"
APP_LOGS_DIR="${APP_HOME}/logs"

mkdir -p $APP_CONF_DIR
mkdir -p $APP_LOGS_DIR

@go.log INFO "Getting default conf from image"

CID=$(sudo docker run -d $APP_IMG sleep 20)
sudo docker cp $CID:/$APP_VER_DIR/conf_orig/ ${APP_CONF_DIR}/
sudo docker kill $CID
sudo docker rm $CID
sudo mv ${APP_CONF_DIR}/conf_orig/* $APP_CONF_DIR/
sudo rm -rf $APP_CONF_DIR/conf_orig
sudo chown -R zetaadm:zetaproddata $APP_CONF_DIR


cat > ${APP_CONF_DIR}/docker_start.sh << EOF4
#!/bin/bash
export HBASE_LOGFILE="hbaserest-\$HOST-\$HOSTNAME.log"
env
/${APP_VER_DIR}/bin/hbase rest start -p 8000 --infoport 8005
EOF4


chmod +x ${APP_CONF_DIR}/docker_start.sh



cat > $APP_ENV_FILE << EOL1
#!/bin/bash
export ZETA_${APP_NAME}_${APP_ID}_PORT="${APP_PORT}"
export ZETA_${APP_NAME}_${APP_ID}_INFO_PORT="${APP_INFO_PORT}"
EOL1

ZK=$(echo $ZETA_ZKS|cut -d"," -f1)
ZK_PORT=$(echo $ZK|cut -d":" -f2)
ZKS_NOPORT=$(echo $ZETA_ZKS|sed "s/:${ZK_PORT}//g")



cat > ${APP_HOME}/conf/hbase-site.xml << EOFCONF
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!--
/**
 * Copyright 2010 The Apache Software Foundation
 *
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
-->
<configuration>

  <property>
    <name>hbase.rootdir</name>
    <value>maprfs:///hbase</value>
  </property>

  <property>
<name>hbase.cluster.distributed</name>
<value>true</value>
  </property>

  <property>
<name>hbase.zookeeper.quorum</name>
<value>${ZKS_NOPORT}</value>
  </property>

  <property>
<name>hbase.zookeeper.property.clientPort</name>
<value>${ZK_PORT}</value>
  </property>

<property>
    <name>dfs.support.append</name>
    <value>true</value>
  </property>

  <property>
    <name>hbase.fsutil.maprfs.impl</name>
    <value>org.apache.hadoop.hbase.util.FSMapRUtils</value>
  </property>
  <property>
    <name>hbase.regionserver.handler.count</name>
    <value>30</value>
    <!-- default is 25 -->
  </property>

  <!-- uncomment this to enable fileclient logging
  <property>
    <name>fs.mapr.trace</name>
    <value>debug</value>
  </property>
  -->

  <!-- Allows file/db client to use 64 threads -->
  <property>
    <name>fs.mapr.threads</name>
    <value>64</value>
  </property>


  <property>
    <name>mapr.hbase.default.db</name>
    <value>maprdb</value>
  </property>

  <property>
    <name>hbase.table.namespace.mappings</name>
        <value>*:${APP_TABLE_ROOT}/</value> 
  </property>
</configuration>
EOFCONF

MAPR_HOME="/opt/mapr"
HDIR=$(ls -1 $MAPR_HOME/hadoop/|grep "hadoop-2")
HADOOP_HOME="$MAPR_HOME/hadoop/$HDIR"

cat > $APP_MAR_FILE << EOF
{
  "id": "${APP_MAR_ID}",
  "cpus": ${APP_CPU},
  "mem": ${APP_MEM},
  "instances": 1,
  "cmd":"su -c /$APP_VER_DIR/conf/docker_start.sh ${APP_USER}",
  "labels": {
   $APP_HA_PROXY
   "CONTAINERIZER":"Docker"
  },
  "env": {
    "HBASE_HOME": "/${APP_VER_DIR}",
    "HADOOP_HOME": "${HADOOP_HOME}",
    "HBASE_LOG_DIR": "/${APP_VER_DIR}/logs",
    "HBASE_ROOT_LOGGER": "INFO,RFA",
    "HBASE_CLASSPATH_PREFIX":"/${APP_VER_DIR}/lib/*:/opt/mapr/lib/*",
    "JAVA_HOME": "/usr/lib/jvm/java-8-openjdk-amd64"
  },
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${APP_IMG}",
      "network": "BRIDGE",
      "portMappings": [
        ${APP_PORT_JSON},
        ${APP_INFO_PORT_JSON}
      ]
    },
  "volumes": [
      {
        "containerPath": "/${APP_VER_DIR}/logs",
        "hostPath": "${APP_HOME}/logs",
        "mode": "RW"
      },
      {
        "containerPath": "/opt/mapr",
        "hostPath": "/opt/mapr",
        "mode": "RO"
      },
      {
        "containerPath": "/${APP_VER_DIR}/conf",
        "hostPath": "${APP_HOME}/conf",
        "mode": "RO"
      }
    ]
  }
}
EOF



##########
# Provide instructions for next steps
echo ""
echo ""
echo "$APP_NAME instance ${APP_ID} installed at ${APP_HOME} and ready to go"
echo "To start please run: "
echo ""
echo "$ ./zeta package start ${APP_HOME}/$APP_ID.conf"
echo ""



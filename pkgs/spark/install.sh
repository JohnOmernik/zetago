#!/bin/bash



@go.log INFO "Unpacking TGZ File to Instance Root"
tar zxf $APP_PKG_DIR/$APP_TGZ -C $APP_HOME
mkdir -p $APP_HOME/sparklogs
sudo chown -R $IUSER:zeta${APP_ROLE}zeta $APP_HOME/sparklogs


@go.log INFO "Checking for Active CLDB"
CLDBS=$(echo "$ZETA_CLDBS"|tr "," " ")
for C in $CLDBS; do
    OUT=$(hadoop fs -ls maprfs://$C/ 2> /dev/null)
    if [ "$OUT" != "" ]; then
        CLDB="$C"
        break
    fi
done
if [ "$CLDB" == "" ]; then
    @go.log FATAL "Could not determine CLDB"
fi



APP_MAR_HIST_FILE="${APP_HOME}/marathon_hist.json"
APP_MAR_SHUF_FILE="${APP_HOME}/marathon_shuf.json"

APP_MAR_HIST_ID="${APP_ROLE}/${APP_ID}/sparkhistory"
APP_MAR_SHUF_ID="${APP_ROLE}/${APP_ID}/sparkshuffle"


@go.log INFO "Counting active agent nodes with FS"
NODES=$(echo "$INODES"|tr ";" " ")
APP_SHUF_CNT=0
for N in $NODES; do
    APP_SHUF_CNT=$(($APP_SHUF_CNT+1))
done


SOME_COMMENTS="Port for Spark History Server"
PORTSTR="CLUSTER:tcp:23501:${APP_ROLE}:${APP_ID}:$SOME_COMMENTS"
getport "CHKADD" "$SOME_COMMENTS" "$SERVICES_CONF" "$PORTSTR"

if [ "$CHKADD" != "" ]; then
    getpstr "MYTYPE" "MYPROTOCOL" "APP_HIST_PORT" "MYROLE" "MYAPP_ID" "MYCOMMENTS" "$CHKADD"
    APP_HIST_PORTSTR="$CHKADD"
else
    @go.log FATAL "Failed to get Port for $APP_NAME $PSTR"
fi

bridgeports "APP_HIST_PORT_JSON" "18080" "$APP_HIST_PORTSTR"
haproxylabel "APP_HIST_HA_PROXY" "${APP_HIST_PORTSTR}"


read -e -p "Please enter the memory limit for the history server for ${APP_ID} instance of ${APP_NAME}: " -i "1280" APP_HIST_MEM

read -e -p "Please enter the cpu limit for the history server for ${APP_ID} instance of ${APP_NAME}: " -i "1.0" APP_HIST_CPU
echo ""
echo ""


echo "Spark requires local volumes for spill location. If you already have local volumes, great, no need to create them."
echo "If you do not have them, please answer yes to the next question and it will create them for you"
echo "If you are unsure, run it anyways, it won't hurt your volumes if they do exist"
read -e -p "Try local creating volumes? (Y/N): " -i "N" CVOL
if [ "$CVOL" == "Y" ]; then
    ./zeta fs $FS_PROVIDER createlocalvols -a -u
fi


SOME_COMMENTS="Port for Spark Shuffle Server"
PORTSTR="CLUSTER:tcp:7350:${APP_ROLE}:${APP_ID}:$SOME_COMMENTS"
getport "CHKADD" "$SOME_COMMENTS" "$SERVICES_CONF" "$PORTSTR"

if [ "$CHKADD" != "" ]; then
    getpstr "MYTYPE" "MYPROTOCOL" "APP_SHUF_PORT" "MYROLE" "MYAPP_ID" "MYCOMMENTS" "$CHKADD"
    APP_SHUF_PORTSTR="$CHKADD"
else
    @go.log FATAL "Failed to get Port for $APP_NAME $PSTR"
fi
nonbridgeports "APP_SHUF_PORT_LIST" "$APP_SHUF_PORTSTR"
haproxylabel "APP_SHUF_HA_PROXY" "${APP_SHUF_PORTSTR}"


APP_SHUF_CPU="1.0"
APP_SHUF_MEM="1024"
APP_HIST_CNT="1"

echo ""
echo "Spark Resources"
echo ""
read -e -p "Please enter the Max number of dynamic executors: " -i "10" APP_SPARK_MAX_EXECUTORS
read -e -p "Please enter the amount of Memory for the Spark Driver: " -i "512m" APP_SPARK_DRIVER_MEM
read -e -p "Please enter the amount of Memory for the Spark Executor: " -i "4096m" APP_SPARK_EXECUTOR_MEM
read -e -p "What is the total max cores to use for this instance: " -i "24" APP_SPARK_MAX_CORES
read -e -p "What is the cores per executor to use for this instance: " -i "4" APP_SPARK_CORES_PER_EXECUTOR
read -e -p "What is the minimim number of executors for this instance: " -i "1" APP_SPARK_MIN_EXECUTORS
read -e -p "What is the initial number of executors for this instance: " -i "1" APP_SPARK_INIT_EXECUTORS


cat > ${APP_ENV_FILE} << EOL1
#!/bin/bash
export ZETA_${APP_ID}__HISTORY_PORT="${APP_PORT}"
EOL1


@go.log INFO "Creating a Docker Run file for $APP_NAME instance $APP_ID"
cat > $APP_HOME/run.sh << EOL
#!/bin/bash

IMG="$APP_IMG"
SPARK="-v=${APP_HOME}/${APP_VER_DIR}:/spark:ro"

FSVOL="-v=${FS_HOME}:${FS_HOME}:ro"
MESOSLIB="-v=/opt/mesosphere:/opt/mesosphere:ro"
NET="--net=host"

U="--user nobody"

if [ -f "/usr/bin/sudo" ]; then
    sudo docker run -it --rm \$U \$NET \$SPARK \$FSVOL \$MESOSLIB \$IMG /bin/bash
else
    docker run -it --rm \$U \$NET \$SPARK \$FSVOL \$MESOSLIB \$IMG /bin/bash
fi

EOL

chmod +x $APP_HOME/run.sh


@go.log WARN "Need to genericize FS library loading"
MAPR_HOME="$FS_HOME"
HADOOP_HOME="$FS_HADOOP_HOME"

@go.log INFO "Creating spark-env.sh"
cat > ${APP_HOME}/${APP_VER_DIR}/conf/spark-env.sh << EOE
#!/usr/bin/env bash
export JAVA_LIBRARY_PATH=/opt/mesosphere/lib
export MESOS_NATIVE_JAVA_LIBRARY=/opt/mesosphere/lib/libmesos.so
export LD_LIBRARY_PATH=/opt/mesosphere/lib
export JAVA_HOME=/opt/mesosphere/active/java/usr/java

export HADOOP_HOME="$HADOOP_HOME"
export MAPR_HOME="$MAPR_HOME"

HNAME=\$(hostname -f)
APP_ID="$APP_ID"
TMP_LOC="${CLUSTERMOUNT}${FS_PROVIDER_LOCAL}/\$HNAME/local/spark/\$APP_ID"
ME=\$(whoami)
if [ "\$ME" == "root" ]; then
    echo "TMP_LOC: \$TMP_LOC"
    mkdir -p \$TMP_LOC
    chown -R $IUSER:zeta${APP_ROLE}zeta \$TMP_LOC
    chmod -R 775 \$TMP_LOC
fi
ln -s \$TMP_LOC /tmp/spark

ls -ls ${CLUSTERMOUNT}${FS_PROVIDER_LOCAL}/\$HNAME/local/spark


export HADOOP_CONF_DIR=\${HADOOP_HOME}/etc/hadoop
MAPR_HADOOP_CLASSPATH=\`\${HADOOP_HOME}/bin/hadoop classpath\`:\`ls \$MAPR_HOME/lib/slf4j-log*\`:
MAPR_HADOOP_JNI_PATH=\`\${HADOOP_HOME}/bin/hadoop jnipath\`
export SPARK_LIBRARY_PATH=\$MAPR_HADOOP_JNI_PATH
MAPR_SPARK_CLASSPATH="\$MAPR_HADOOP_CLASSPATH"
SPARK_DIST_CLASSPATH=\$MAPR_SPARK_CLASSPATH
# Security status
source \$MAPR_HOME/conf/env.sh
if [ "\$MAPR_SECURITY_STATUS" = "true" ]; then
SPARK_SUBMIT_OPTS="\$SPARK_SUBMIT_OPTS -Dmapr_sec_enabled=true"
fi

EOE


@go.log INFO "Creating spark-defaults.conf"
MAPRCP=$(ls -1 ${MAPR_HOME}/lib/maprfs-*|grep -v diagnostic|tr "\n" ":")
YARNCP=$(ls $HADOOP_HOME/share/hadoop/yarn/hadoop-yarn-common-*)

cat > ${APP_HOME}/${APP_VER_DIR}/conf/spark-defaults.conf << EOC
spark.master                       mesos://leader.mesos:5050

spark.serializer                 org.apache.spark.serializer.KryoSerializer
spark.driver.memory              $APP_SPARK_DRIVER_MEM
spark.executor.memory            $APP_SPARK_EXECUTOR_MEM
spark.cores.max                  $APP_SPARK_MAX_CORES
spark.executor.cores             $APP_SPARK_CORES_PER_EXECUTOR

spark.sql.hive.metastore.sharedPrefixes com.mysql.jdbc,org.postgresql,com.microsoft.sqlserver,oracle.jdbc,com.mapr.fs.shim.LibraryLoader,com.mapr.security.JNISecurity,com.mapr.fs.jni

spark.executor.extraClassPath   ${YARNCP}:${MAPRCP}
spark.network.timeout 15s

spark.mesos.executor.docker.image $APP_IMG
spark.mesos.executor.docker.volumes ${APP_HOME}/${APP_VER_DIR}:/spark:ro,${FS_HOME}:${FS_HOME}:ro,/opt/mesosphere:/opt/mesosphere:ro,${CLUSTERMOUNT}${FS_PROVIDER_LOCAL}:${CLUSTERMOUNT}${FS_PROVIDER_LOCAL}:rw

spark.home  /spark
spark.local.dir /tmp/spark

spark.eventLog.enabled true
spark.eventLog.dir maprfs://$CLDB/$APP_DIR/$APP_ROLE/$APP_NAME/$APP_ID/sparklogs
spark.history.fs.cleaner.enabled    true
spark.history.fs.cleaner.interval   1d
spark.history.fs.cleaner.maxAge 7d
spark.history.fs.logDirectory maprfs://$CLDB/$APP_DIR/$APP_ROLE/$APP_NAME/$APP_ID/sparklogs

spark.shuffle.service.enabled true
spark.shuffle.io.connectionTimeout 10s
spark.shuffle.service.port $APP_SHUF_PORT

spark.dynamicAllocation.enabled true
spark.dynamicAllocation.minExecutors $APP_SPARK_MIN_EXECUTORS
spark.dynamicAllocation.initialExecutors $APP_SPARK_INIT_EXECUTORS
spark.dynamicAllocation.maxExecutors $APP_SPARK_MAX_EXECUTORS
spark.dynamicAllocation.executorIdleTimeout 60s

EOC


cat > $APP_MAR_SHUF_FILE << EOQ
{
  "id": "${APP_MAR_SHUF_ID}",
  "cpus": $APP_SHUF_CPU,
  "mem": $APP_SHUF_MEM,
  "cmd":"cd /spark && ./sbin/start-mesos-shuffle-service.sh",
  "instances": $APP_SHUF_CNT,
  "labels": {
   $APP_SHUF_HA_PROXY
   "CONTAINERIZER":"Docker"
  },
  "env": {
    "SPARK_NO_DAEMONIZE": "1",
    "SPARK_DAEMON_MEMORY": "1g"
  },
  "constraints": [
    [ "hostname", "UNIQUE"]
  ],
  $APP_SHUF_PORT_LIST
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${APP_IMG}",
      "network": "HOST"
    },
  "volumes": [
      {
        "containerPath": "/spark",
        "hostPath": "${APP_HOME}/${APP_VER_DIR}",
        "mode": "RW"
      },
      {
        "containerPath": "${FS_HOME}",
        "hostPath": "${FS_HOME}",
        "mode": "RO"
      },
      {
        "containerPath": "/opt/mesosphere",
        "hostPath": "/opt/mesophere",
        "mode": "RO"
      },
      {
        "containerPath": "${CLUSTERMOUNT}${FS_PROVIDER_LOCAL}",
        "hostPath": "${CLUSTERMOUNT}${FS_PROVIDER_LOCAL}",
        "mode": "RW"
      }
    ]
  }
}
EOQ

cat > $APP_MAR_HIST_FILE << EOM
{
  "id": "${APP_MAR_HIST_ID}",
  "cpus": $APP_HIST_CPU,
  "mem": $APP_HIST_MEM,
  "cmd":"cd /spark && ./sbin/start-history-server.sh",
  "instances": ${APP_HIST_CNT},
  "labels": {
   $APP_HIST_HA_PROXY
   "CONTAINERIZER":"Docker"
  },
  "env": {
    "SPARK_NO_DAEMONIZE": "1"
  },
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${APP_IMG}",
      "network": "BRIDGE",
      "portMappings": [
        $APP_HIST_PORT_JSON
      ]
    },
  "volumes": [
      {
        "containerPath": "/spark",
        "hostPath": "${APP_HOME}/${APP_VER_DIR}",
        "mode": "RW"
      },
      {
        "containerPath": "${FS_HOME}",
        "hostPath": "${FS_HOME}",
        "mode": "RO"
      },
      {
        "containerPath": "/opt/mesosphere",
        "hostPath": "/opt/mesophere",
        "mode": "RO"
      }
    ]
  }
}

EOM



echo ""
echo "Spark Instance $APP_ID is installed at $APP_HOME"
echo "You can run a docker container with all info via $APP_HOME/run.sh"
echo "Once inside this container:"
echo "1. Authenticate as a user who has access to the data (example: su zetasvc${APP_ROLE})"
echo "2. cd /spark"
echo "3. bin/pyspark"
echo ""
echo "This is a basic/poc install, changes can be made via the conf files"
echo ""
echo ""
echo "In addition, you can start the spark history server by running:"
echo ""
echo "$ ./zeta package start ${APP_HOME}/$APP_ID.conf"
echo ""

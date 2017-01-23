#!/bin/bash



@go.log INFO "Unpacking TGZ File to Instance Root"
tar zxf $APP_PKG_DIR/$APP_TGZ -C $APP_HOME
mkdir -p $APP_HOME/sparklogs

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



SOME_COMMENTS="Port for Spark History Server"
PORTSTR="CLUSTER:tcp:23501:${APP_ROLE}:${APP_ID}:$SOME_COMMENTS"
getport "CHKADD" "$SOME_COMMENTS" "$SERVICES_CONF" "$PORTSTR"

if [ "$CHKADD" != "" ]; then
    getpstr "MYTYPE" "MYPROTOCOL" "APP_PORT" "MYROLE" "MYAPP_ID" "MYCOMMENTS" "$CHKADD"
    APP_PORTSTR="$CHKADD"
else
    @go.log FATAL "Failed to get Port for $APP_NAME $PSTR"
fi

bridgeports "APP_PORT_JSON" "18080" "$APP_PORTSTR"
haproxylabel "APP_HA_PROXY" "${APP_PORTSTR}"


read -e -p "Please enter the memory limit for the history server for ${APP_ID} instance of ${APP_NAME}: " -i "1280" APP_MEM

read -e -p "Please enter the cpu limit for the history server for ${APP_ID} instance of ${APP_NAME}: " -i "1.0" APP_CPU
APP_CNT="1"

cat > ${APP_ENV_FILE} << EOL1
#!/bin/bash
export ZETA_${APP_ID}__HISTORY_PORT="${APP_PORT}"
EOL1



@go.log INFO "Creating a Docker Run file for $APP_NAME instance $APP_ID"
cat > $APP_HOME/run.sh << EOL
#!/bin/bash

IMG="$APP_IMG"

SPARK="-v=${APP_HOME}/${APP_VER_DIR}:/spark:ro"

MAPR="-v=/opt/mapr:/opt/mapr:ro"
MESOSLIB="-v=/opt/mesosphere:/opt/mesosphere:ro"
NET="--net=host"

U="--user nobody"

if [ -f "/usr/bin/sudo" ]; then
    sudo docker run -it --rm \$U \$NET \$SPARK \$MAPR \$MESOSLIB \$IMG /bin/bash
else
    docker run -it --rm \$U \$NET \$SPARK \$MAPR \$MESOSLIB \$IMG /bin/bash
fi

EOL

chmod +x $APP_HOME/run.sh


# These are Calculated for a MapR install
MAPR_HOME="/opt/mapr"
HDIR=$(ls -1 $MAPR_HOME/hadoop/|grep "hadoop-2")
HADOOP_HOME="$MAPR_HOME/hadoop/$HDIR"


@go.log INFO "Creating spark-env.sh"
cat > ${APP_HOME}/${APP_VER_DIR}/conf/spark-env.sh << EOE
#!/usr/bin/env bash
export JAVA_LIBRARY_PATH=/opt/mesosphere/lib
export MESOS_NATIVE_JAVA_LIBRARY=/opt/mesosphere/lib/libmesos.so
export LD_LIBRARY_PATH=/opt/mesosphere/lib
export JAVA_HOME=/opt/mesosphere/active/java/usr/java

export MAPR_HOME="$MAPR_HOME"
export HADOOP_HOME="$HADOOP_HOME"

export HADOOP_CONF_DIR=\${HADOOP_HOME}/etc/hadoop
MAPR_HADOOP_CLASSPATH=\`\${HADOOP_HOME}/bin/hadoop classpath\`:\`ls \$MAPR_HOME/lib/slf4j-log*\`:
MAPR_HADOOP_JNI_PATH=\`\${HADOOP_HOME}/bin/hadoop jnipath\`
export SPARK_LIBRARY_PATH=\$MAPR_HADOOP_JNI_PATH
MAPR_SPARK_CLASSPATH="\$MAPR_HADOOP_CLASSPATH"
SPARK_DIST_CLASSPATH=\$MAPR_SPARK_CLASSPATH
# Security status
source /opt/mapr/conf/env.sh
if [ "\$MAPR_SECURITY_STATUS" = "true" ]; then
SPARK_SUBMIT_OPTS="\$SPARK_SUBMIT_OPTS -Dmapr_sec_enabled=true"
fi

EOE

echo ""
echo "Resources"
read -e -p "Please enter the amount of Memory for the Spark Driver: " -i "512m" APP_SPARK_DRIVER_MEM
read -e -p "Please enter the amount of Memory for the Spark Executor: " -i "4096m" APP_SPARK_EXECUTOR_MEM


@go.log INFO "Creating spark-defaults.conf"
MAPRCP=$(ls -1 ${MAPR_HOME}/lib/maprfs-*|grep -v diagnostic|tr "\n" ":")
YARNCP=$(ls $HADOOP_HOME/share/hadoop/yarn/hadoop-yarn-common-*)

cat > ${APP_HOME}/${APP_VER_DIR}/conf/spark-defaults.conf << EOC
spark.master                       mesos://leader.mesos:5050

spark.serializer                 org.apache.spark.serializer.KryoSerializer
spark.driver.memory              $APP_SPARK_DRIVER_MEM
spark.executor.memory            $APP_SPARK_EXECUTOR_MEM

spark.sql.hive.metastore.sharedPrefixes com.mysql.jdbc,org.postgresql,com.microsoft.sqlserver,oracle.jdbc,com.mapr.fs.shim.LibraryLoader,com.mapr.security.JNISecurity,com.mapr.fs.jni

spark.executor.extraClassPath   ${YARNCP}:${MAPRCP}

spark.mesos.executor.docker.image $APP_IMG

spark.home  /spark

spark.eventLog.enabled true
spark.eventLog.dir maprfs://$CLDB/$APP_DIR/$APP_ROLE/$APP_ID/sparklogs

spark.mesos.executor.docker.volumes ${APP_HOME}/${APP_VER_DIR}:/spark:ro,/opt/mapr:/opt/mapr:ro,/opt/mesosphere:/opt/mesosphere:ro

spark.history.fs.cleaner.enabled    true

spark.history.fs.cleaner.interval   1d

spark.history.fs.cleaner.maxAge 7d

spark.history.fs.logDirectory maprfs://$CLDB/$APP_DIR/$APP_ROLE/$APP_ID/sparklogs


EOC

cat > $APP_MAR_FILE << EOM
{
  "id": "${APP_MAR_ID}",
  "cpus": $APP_CPU,
  "mem": $APP_MEM,
  "cmd":"cd /spark && ./sbin/start-history-server.sh",
  "instances": ${APP_CNT},
  "labels": {
   $APP_HA_PROXY
   "CONTAINERIZER":"Docker"
  },
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
      {
        "containerPath": "/spark",
        "hostPath": "${APP_HOME}/${APP_VER_DIR}",
        "mode": "RW"
      },
      {
        "containerPath": "/opt/mapr",
        "hostPath": "/opt/mapr",
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

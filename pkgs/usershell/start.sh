#!/bin/bash



. ${APP_HOME}/instance_include.sh

echo "This script both installs and starts new users in the $APP_ID instance of $APP_NAME"

echo ""
read -e -p "What is the username you wish to install this instance of usershell for? " APP_USER
echo ""


APP_USER_ID=$(id $APP_USER)
APP_USER_HOME="/mapr/$CLUSTERNAME/user/$APP_USER"
APP_MAR_FILE="${APP_HOME}/marathon/user_shell_${APP_USER}_marathon.json"
APP_USER_PATH="${APP_USER_HOME}/bin"

#Instance checks
STARTME="N"
if [ "$APP_USER_ID" == "" ]; then
    @go.log FATAL "Cannot determined UID for user $APP_USER - Can Not Proceed"
fi
if [ ! -d "$APP_USER_HOME" ]; then
    @go.log FATAL "Cannot find user home directory for $APP_USER at /mapr/$CLUSTERNAME/users - Can Not Proceed"
fi
if [ -f "$APP_MAR_FILE" ]; then
    @go.log WARN "There is already an instance file for $APP_USER running usershell, do you wish to start?"
    read -e -p "Start usershell for $APP_USER? " -i "Y" STARTME
    if [ "$STARTME" != "Y" ]; then
        @go.log FATAL "Will not proceed to create new confs for usershell for $APP_USER"
    fi
fi

if [ "$STARTME" == "N" ]; then 
    mkdir -p ${APP_USER_PATH}
    DEF_FILES="profile nanorc bashrc"
    echo ""
    echo "Copying default $DEF_FILES to $APP_USER_HOME"
    echo ""

    for DFILE in $DEF_FILES; do
        SRCFILE="${DFILE}_template"
        DSTFILE=".${DFILE}"
        if [ -f "${APP_USER_HOME}/${DSTFILE}" ]; then
            read -e -p "${APP_USER_HOME}/${DSTFILE} exists, should we replace it with the default $DSTFILE? " -i "N" CPFILE
        else
            CPFILE="Y"
        fi

        if [ "$CPFILE" == "Y" ]; then
            sudo cp ${APP_HOME}/$SRCFILE ${APP_USER_HOME}/$DSTFILE
            sudo chown $APP_USER:zetaadm ${APP_USER_HOME}/$DSTFILE
        fi
    done

    INSTRUCTIONS=$(grep "Zeta User Shell" ${APP_USER_HOME}/.profile)

    if [ "$INSTRUCTIONS" == "" ]; then

sudo tee -a ${APP_USER_HOME}/.profile << EOF
CLUSTERNAME=\$(ls /mapr)
echo ""
echo "**************************************************************************"
echo "Zeta Cluster User Shell"
echo ""
echo "This simple shell is a transient container that allows you to do some basic exploration of the Zeta Environment"
echo ""
echo "Components to be aware of:"
echo "- If a Drill Instance was installed with this shell, you can run a Drill Command Line Shell (SQLLine) by simply typing 'zetadrill' and following the authentication prompts"
echo "- If a Spark instance was installed with this shell, you can run a Spark pyspark interactive shell by by simply typing 'zetaspark'"
echo "- Java is in the path and available for use"
echo "- Python is installed and in the path"
echo "- The hadoop client (i.e. hadoop fs -ls /) is in the path and available"
echo "- While the container is not persistent, the user's home directory IS persistent. Everything in /home/$USER will be maintained after the container expires"
echo "- /mapr/\$CLUSTERNAME is also persistent.  This is root of the distributed file system. (I.e. ls /mapr/\$CLUSTERNAME has the same result as hadoop fs -ls /)"
echo "- The user's home directory is also in the distributed filesystem. Thus, if you save a file to /home/\$USER it also is saved at /mapr/\$CLUSTERNAME/user/\$USER. THis is usefule for running distributed drill queries."
echo ""
echo "This is a basic shell environment. It does NOT have the ability to run docker commands, and we would be very interested in other feature requests."
echo ""
echo "**************************************************************************"
echo ""
EOF
    fi

    MAPR_HOME="/opt/mapr"
    HDIR=$(ls -1 $MAPR_HOME/hadoop/|grep "hadoop-2")
    HADOOP_HOME="$MAPR_HOME/hadoop/$HDIR"

    @go.log INFO "Linking Hadoop Client for use in Container"
    ln -s $HADOOP_HOME/bin/hadoop ${APP_USER_PATH}/hadoop



    PORTSTR="CLUSTER:tcp:31022:${APP_ROLE}:${APP_ID}:Usershell for $APP_USER"
    getport "CHKADD" "Usershell for $APP_USER" "$SERVICES_CONF" "$PORTSTR"

    if [ "$CHKADD" != "" ]; then
        getpstr "MYTYPE" "MYPROTOCOL" "APP_PORT" "MYROLE" "MYAPP_ID" "MYCOMMENTS" "$CHKADD"
        APP_PORTSTR="$CHKADD"
    else
        @go.log FATAL "Failed to get Port for usershell instance $PSTR"
    fi


    APP_MAR_ID="${APP_ROLE}/${APP_ID}/${APP_USER}usershell"

    echo ""
    echo "You can customize your usershell env to utilize already established instances of some packages. You can skip this step if desired"
    echo ""
    read -e -p "Do you wish to skip instance customization? Answering anything except Y will run through some additional questions: " -i "N" SKIPCUSTOM
    echo ""

    if [ "$SKIPCUSTOM" != "Y" ]; then
        echo "The first package we will be offering for linking into the env is Apache Drill"
        PKG="drill"
        read -e -p "Enter instance name of $PKG you wish to associate with this usershell instance (blank if none): " PKG_ID
        read -e -p "What role is this instance of $PKG in? " PKG_ROLE

        if [ "$PKG_ID" != "" ]; then
            DRILL_PKG_HOME="/mapr/$CLUSTERNAME/zeta/$PKG_ROLE/$PKG/$PKG_ID"
            if [ ! -d "${DRILL_PKG_HOME}" ]; then
                echo "Instance home not found, skipping"
            else
                ln -s ${DRILL_PKG_HOME}/zetadrill ${APP_USER_PATH}/zetadrill
            fi
        fi

        echo "The next package we will be offering for linking into the env is Apache Spark"
        PKG="spark"
        read -e -p "Enter instance name of $PKG you wish to associate with this usershell instance (blank if none): " PKG_ID
        read -e -p "What role is this instance of $PKG in? " PKG_ROLE

        if [ "$PKG_ID" != "" ]; then
            SPARK_PKG_HOME="/mapr/$CLUSTERNAME/zeta/$PKG_ROLE/$PKG/$PKG_ID"
            if [ ! -d "${SPARK_PKG_HOME}" ]; then
                echo "Instance home not found, skipping"
            else
cat > ${APP_USER_PATH}/zetaspark << EOS
#!/bin/bash
SPARK_HOME="/spark"
cd \$SPARK_HOME
bin/pyspark
EOS
                chmod +x ${APP_USER_PATH}/zetaspark
            fi
        fi
    fi
    nonbridgeports "APP_PORT_LIST" "${APP_PORTSTR}"

    if [ -d "$SPARK_PKG_HOME" ]; then
        SPARK_HOME_SHORT=$(ls -1 ${SPARK_PKG_HOME}|grep -v "run\.sh"|grep -v "${PKG_ID}\.conf")
        SPARK_HOME="${SPARK_PKG_HOME}/$SPARK_HOME_SHORT"

        echo "Using $SPARK_HOME for spark home"



cat > $APP_MAR_FILE << EOM
{
  "id": "${APP_MAR_ID}",
  "cpus": $APP_CPU,
  "mem": $APP_MEM,
  "cmd": "sed -i \"s/Port 22/Port ${APP_PORT}/g\" /etc/ssh/sshd_config && /usr/sbin/sshd -D",
  "instances": 1,
  "labels": {
   "CONTAINERIZER":"Docker"
  },
  ${APP_PORT_LIST}
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${APP_IMG}",
      "network": "HOST"
    },
  "volumes": [
      { "containerPath": "/opt/mapr", "hostPath": "/opt/mapr", "mode": "RO"},
      { "containerPath": "/opt/mesosphere", "hostPath": "/opt/mesosphere", "mode": "RO"},
      { "containerPath": "/home/$APP_USER", "hostPath": "/mapr/$CLUSTERNAME/user/$APP_USER", "mode": "RW"},
      { "containerPath": "/home/zetaadm", "hostPath": "/mapr/$CLUSTERNAME/user/zetaadm", "mode": "RW"},
      { "containerPath": "/mapr/$CLUSTERNAME", "hostPath": "/mapr/$CLUSTERNAME", "mode": "RW"},
      { "containerPath": "/spark", "hostPath": "${SPARK_HOME}", "mode": "RW"}
    ]
  }
}
EOM
    else
cat > $APP_MAR_FILE << EOU
{
  "id": "${APP_MAR_ID}",
  "cpus": $APP_CPU,
  "mem": $APP_MEM,
  "cmd": "sed -i \"s/Port 22/Port ${APP_PORT}/g\" /etc/ssh/sshd_config && /usr/sbin/sshd -D",
  "instances": 1,
  "labels": {
   "CONTAINERIZER":"Docker"
  },
  ${APP_PORT_LIST}
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${APP_IMG}",
      "network": "HOST"
    },
  "volumes": [
      { "containerPath": "/opt/mapr", "hostPath": "/opt/mapr", "mode": "RO"},
      { "containerPath": "/opt/mesosphere", "hostPath": "/opt/mesosphere", "mode": "RO"},
      { "containerPath": "/home/$APP_USER", "hostPath": "/mapr/$CLUSTERNAME/user/$APP_USER", "mode": "RW"},
      { "containerPath": "/home/zetaadm", "hostPath": "/mapr/$CLUSTERNAME/user/zetaadm", "mode": "RW"},
      { "containerPath": "/mapr/$CLUSTERNAME", "hostPath": "/mapr/$CLUSTERNAME", "mode": "RW"}
    ]
  }
}
EOU
    fi
    read -e -p "Do you wish to start the usershell process for $APP_USER now? " -i "Y" STARTME
fi

if [ "$STARTME" == "Y" ]; then
    CUR_STATUS=$(./zeta cluster marathon getinfo $APP_MAR_ID $MARATHON_SUBMIT)
    EXISTS=$(echo $CUR_STATUS|grep "does not exist")

    SUBMIT="0"
    START="0"

    if [ "$EXISTS" == "" ]; then
        RUNNING=$(echo $CUR_STATUS|grep "TASK_RUNNING")
        if [ "$RUNNING" != "" ]; then
            @go.log WARN "Task $APP_MAR_ID already exists on cluster and is in a TASK_RUNNING state. Will not attempt to start"
        else
            START="1"
        fi
    else
        SUBMIT="1"
    fi
    if [ "$SUBMIT" == "1" ]; then
        ./zeta cluster marathon submit $APP_MAR_FILE $MARATHON_SUBMIT 1
        @go.log INFO "Submitting $APP_ID as it hasn't been submitted yet"
    fi
    if [ "$START" == "1" ]; then
        @go.log INFO "Starting $APP_ID and scaling to $APP_CNT instances per conf file"
        ./zeta cluster marathon scale $APP_MAR_ID $1 $MARATHON_SUBMIT 1
    fi
fi

@go.log INFO "Instance of $APP_NAME for $APP_USER can be reached at: ssh -p${APP_PORT} $APP_USER@${APP_USER}usershell-${APP_ID}-${APP_ROLE}.${ZETA_MARATHON_HOST}"




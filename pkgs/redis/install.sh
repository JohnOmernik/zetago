#!/bin/bash

###############
# $APP Specific
echo "The next step will walk through instance defaults for ${APP_ID}"
echo ""
read -e -p "Please enter the CPU shares to use with $APP_NAME: " -i "2.0" APP_CPU
echo ""
echo "For Redis memory, we will take the Marathon Memory limit and subtract 128mb from it for head room"
echo ""
read -e -p "Please enter the Marathon Memory limit to use with $APP_NAME: " -i "2048" APP_MEM
APP_REDIS_MEM=$((APP_MEM-128))
echo ""
echo "The Redis memory limit will be $APP_REDIS_MEM"
echo ""
read -e -p "Do you wish to require a password for your redis server? (Y/N): " -i "Y" REQ_PASS
echo ""
if [ "$REQ_PASS" == "Y" ]; then
    getpass "redisserver" APP_PASS
else
    APP_PASS=""
fi



SOME_COMMENTS="Port for Redis Server"
PORTSTR="CLUSTER:tcp:32122:${APP_ROLE}:${APP_ID}:$SOME_COMMENTS"
getport "CHKADD" "$SOME_COMMENTS" "$SERVICES_CONF" "$PORTSTR"

if [ "$CHKADD" != "" ]; then
    getpstr "MYTYPE" "MYPROTOCOL" "APP_PORT" "MYROLE" "MYAPP_ID" "MYCOMMENTS" "$CHKADD"
    APP_PORTSTR="$CHKADD"
else
    @go.log FATAL "Failed to get Port for $APP_NAME instance $APP_ID with $PSTR"
fi


bridgeports "APP_PORT_JSON" "6379" "$APP_PORTSTR"
haproxylabel "APP_HA_PROXY" "${APP_PORTSTR}"


APP_MAR_FILE="${APP_HOME}/marathon.json"
APP_DATA_DIR="$APP_HOME/data"
APP_CONF_DIR="$APP_HOME/conf"
APP_CONF_FILE="${APP_CONF_DIR}/redis.conf"
APP_LOG_DIR="$APP_HOME/logs"
APP_ENV_FILE="/mapr/$CLUSTERNAME/zeta/kstore/env/env_${APP_ROLE}/${APP_NAME}_${APP_ID}.sh"


mkdir -p $APP_DATA_DIR
mkdir -p $APP_CONF_DIR
mkdir -p $APP_LOG_DIR
mkdir -p ${APP_HOME}/lock
sudo chmod 770 $APP_DATA_DIR
sudo chmod 770 $APP_CONF_DIR
sudo chmod 770 $APP_LOG_DIR


cat > $APP_ENV_FILE << EOL1
#!/bin/bash
export ZETA_${APP_NAME}_${APP_ID}_PORT="${APP_PORT}"
EOL1




# Update config file for redis

cp ./pkgs/redis/redis_conf.template ${APP_CONF_FILE}

sed -i "s@dir ./@dir /data@g" ${APP_CONF_FILE} # Update the data dir location from ./ to /data (inside the container)

if [ "$APP_PASS" != "" ]; then
    sed -i "s/# requirepass foobared/requirepass $APP_PASS/g" ${APP_CONF_FILE}
fi
sed -i "s/# maxmemory <bytes>/maxmemory ${APP_REDIS_MEM}mb/g" ${APP_CONF_FILE}

@go.log WARN "Setting the maxmemory policy to volitile-lru - please adjust in $APP_CONF_FILE if needed"

sed -i "s/# maxmemory-policy noeviction/maxmemory-policy volatile-lru/g" ${APP_CONF_FILE}

@go.log WARN "Setting the append only file"
sed -i "s/appendonly no/appendonly yes/g" ${APP_CONFIG_FILE}


cat  > ${APP_HOME}/lock/run.sh << EOL2
#!/bin/bash
chmod +x /entrypoint.sh
/docker-entrypoint.sh redis-server /conf/redis.conf
EOL2

chmod +x ${APP_HOME}/lock/run.sh

cat > ${APP_HOME}/lock/lockfile.sh << EOL3
#!/bin/bash

#The location the lock will be attempted in
LOCKROOT="/lock"
LOCKDIRNAME="lock"
LOCKFILENAME="mylock.lck"

#This is the command to run if we get the lock.
RUNCMD="/lock/run.sh"

#Number of seconds to consider the Lock stale, this could be application dependent.
LOCKTIMEOUT=60
SLEEPLOOP=30

LOCKDIR=\${LOCKROOT}/\${LOCKDIRNAME}
LOCKFILE=\${LOCKDIR}/\${LOCKFILENAME}


if mkdir "\${LOCKDIR}" &>/dev/null; then
    echo "No Lockdir. Our lock"
    # This means we created the dir!
    # The lock is ours
    # Run a sleep loop that puts the file in the directory
    while true; do date +%s > \$LOCKFILE ; sleep \$SLEEPLOOP; done &
    #Now run the real shell scrip
    \$RUNCMD
else
    #Pause to allow another lock to start
    sleep 1
    if [ -e "\$LOCKFILE" ]; then
        echo "lock dir and lock file Checking Stats"
        CURTIME=\`date +%s\`
        FILETIME=\`cat \$LOCKFILE\`
        DIFFTIME=\$((\$CURTIME-\$FILETIME))
        echo "Filetime \$FILETIME"
        echo "Curtime \$CURTIME"
        echo "Difftime \$DIFFTIME"

        if [ "\$DIFFTIME" -gt "\$LOCKTIMEOUT" ]; then
            echo "Time is greater then Timeout We are taking Lock"
            # We should take the lock! First we remove the current directory because we want to be atomic
            rm -rf \$LOCKDIR
            if mkdir "\${LOCKDIR}" &>/dev/null; then
                while true; do date +%s > \$LOCKFILE ; sleep \$SLEEPLOOP; done &
                \$RUNCMD
            else
                echo "Cannot Establish Lock file"
                exit 1
            fi
        else
            # The lock is not ours.
            echo "Cannot Estblish Lock file - Active "
            exit 1
        fi
    else
        # We get to be the locker. However, we need to delete the directory and recreate so we can be all atomic about
        rm -rf \$LOCKDIR
        if mkdir "\${LOCKDIR}" &>/dev/null; then
            while true; do date +%s > \$LOCKFILE ; sleep \$SLEEPLOOP; done &
            \$RUNCMD
        else
            echo "Cannot Establish Lock file - Issue"
            exit 1
        fi
    fi
fi
EOL3

chmod +x ${APP_HOME}/lock/lockfile.sh


cat > $APP_MAR_FILE << EOL
{
  "id": "${APP_MAR_ID}",
  "cmd": "/lock/lockfile.sh",
  "cpus": ${APP_CPU},
  "mem": ${APP_MEM},
  "instances": 1,
  "labels": {
   $APP_HA_PROXY
   "CONTAINERIZER":"Docker"
  },
  "ports": [],
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
      { "containerPath": "/data", "hostPath": "${APP_DATA_DIR}", "mode": "RW" },
      { "containerPath": "/conf", "hostPath": "${APP_CONF_DIR}", "mode": "RO" },
      { "containerPath": "/log", "hostPath": "${APP_LOG_DIR}", "mode": "RW" },
      { "containerPath": "/lock", "hostPath": "${APP_HOME}/lock", "mode": "RW" }
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



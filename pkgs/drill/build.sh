#!/bin/bash

checkdocker

check4package "$APP_TGZ" BUILD

reqdockerimg "buildbase_mapr"


# Drill Specific Directories in the shared staging location
mkdir -p ${APP_ROOT}/extrajars
mkdir -p ${APP_ROOT}/libjpam
echo "Place to store custom jars" > ${APP_ROOT}/extrajars/jars.txt


# Check for libjpam (Required)
JPAM=$(ls ${APP_ROOT}/libjpam)
if [ "$JPAM" == "" ]; then
    echo "No Lib JPAM found, should we grab one from a MapR container?"
    @go.log WARN "No libjpam found in APP_ROOT"
    if [ "$UNATTEND" != "1" ]; then
        read -e -p "Pull libjpam.so from maprdocker? " -i "Y" PULLJPAM
    else
        @go.log WARN "Since -u provided, we will automatically pull libjpam"
        PULLJPAM="Y"
    fi
    if [ "$PULLJPAM" == "Y" ]; then
        IMG=$(sudo docker images --format "{{.Repository}}:{{.Tag}}"|grep \/maprdocker)
        CID=$(sudo docker run -d $IMG /bin/bash)
        sudo docker cp $CID:/opt/mapr/lib/libjpam.so $APP_ROOT/libjpam
    else
        @go.log FATAL "Cannot continue with Drill installation without libjpam - exiting"
    fi
fi


# If Build is Y let's do this
if [ "$BUILD" == "Y" ]; then
    rm -rf $BUILD_TMP
    mkdir -p $BUILD_TMP
    cd $BUILD_TMP

    TMP_IMG="zeta/drillbuild"

cat > ./pkg_drill.sh << EOF
wget $APP_URL
rpm2cpio $APP_URL_FILE | cpio -idmv
echo "Moving ./opt/mapr/drill/${APP_VER} to ./"
mv ./opt/mapr/drill/${APP_VER} ./
echo "cd into ${APP_VER}"
cd ${APP_VER}
mv ./conf ./conf_orig
cd ..
chown -R ${IUSER}:${IUSER} ${APP_VER}
tar zcf ${APP_TGZ} ${APP_VER}
rm -rf ./opt
rm -rf ${APP_VER}
rm ${APP_URL_FILE}
EOF
    chmod +x ./pkg_drill.sh

cat > ./Dockerfile << EOL
FROM ${ZETA_DOCKER_REG_URL}/buildbase_mapr
ADD pkg_drill.sh ./
RUN ./pkg_drill.sh
CMD ["/bin/bash"]
EOL

    sudo docker build -t $TMP_IMG .
    sudo docker run --rm -v=`pwd`:/app/tmp $TMP_IMG cp $APP_TGZ /app/tmp/
    sudo docker rmi -f $TMP_IMG
    mv ${APP_TGZ} ${APP_PKG_DIR}/
    cd $MYDIR
    rm -rf $BUILD_TMP
    echo ""
    @go.log INFO "$APP_NAME package build with $APP_VERS_FILE"
    echo ""
else
    @go.log WARN "Not rebuilding $APP_NAME - $APP_VERS_FILE"
fi



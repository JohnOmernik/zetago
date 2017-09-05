#!/bin/bash

checkdocker
check4dockerimage "${APP_IMG_NAME}" BUILD
reqdockerimg "${REQ_APP_IMG_NAME}"



if [ "$BUILD" == "Y" ]; then

    echo "In addition to anaconda2 and anaconda3 base images, we can also add additional libraries for running Apache Spark in Anaconda. Do you wish to do that?"
    read -e -p "Build additional images anaspark2 and anaspark3 based on anaconda images? (Y/N): " -i "Y" BUILD_SPARK
    echo ""


    rm -rf $BUILD_TMP
    mkdir -p $BUILD_TMP
    cd $BUILD_TMP

    # Since BUILD is now "Y" The vers file actually makes the dockerfile
    . ${MYDIR}/${APP_PKG_BASE}/${APP_VERS_FILE}

    cd $MYDIR
    rm -rf $BUILD_TMP
    echo ""
    @go.log INFO "$APP_NAME package build with $APP_VERS_FILE"
    echo ""
else
    @go.log WARN "Not rebuilding $APP_NAME"
fi



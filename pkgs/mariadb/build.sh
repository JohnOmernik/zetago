#!/bin/bash

checkdocker
reqdockerimg "${REQ_APP_IMG_NAME}"
check4dockerimage "${APP_IMG_NAME}" BUILD

if [ "$BUILD" == "Y" ]; then
    @go.log INFO "$APP_NAME is building from $APP_VERS_FILE"
    rm -rf $BUILD_TMP
    mkdir -p $BUILD_TMP
    cd $BUILD_TMP

    # Since BUILD is now "Y" The vers file actually makes the dockerfile
    . ${MYDIR}/${APP_PKG_BASE}/${APP_VERS_FILE}

    sudo docker build --no-cache=true -t $APP_IMG .
    sudo docker push $APP_IMG

    cd $MYDIR
    rm -rf $BUILD_TMP
    echo ""
    @go.log INFO "$APP_NAME package built with $APP_VERS_FILE"
    echo ""
else
    @go.log WARN "Not rebuilding $APP_NAME"
fi

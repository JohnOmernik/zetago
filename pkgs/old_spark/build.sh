#!/bin/bash

checkdocker
check4dockerimage "${APP_IMG_NAME}" BUILD
reqdockerimg "${REQ_APP_IMG_NAME}"


if [ ! -f "${APP_PKG_DIR}/${APP_URL_FILE}" ]; then
    @go.log INFO "$APP_URL_FILE not found in APP_PKG_DIR - Downloading"
    wget ${APP_URL}
    mv ${APP_URL_FILE} ${APP_PKG_DIR}/
fi

if [ "$BUILD" == "Y" ]; then
    rm -rf $BUILD_TMP
    mkdir -p $BUILD_TMP
    cd $BUILD_TMP

    # Since BUILD is now "Y" The vers file actually makes the dockerfile
    . ${MYDIR}/${APP_PKG_BASE}/${APP_VERS_FILE}

    sudo docker build -t $APP_IMG .
    sudo docker push $APP_IMG

    cd $MYDIR
    rm -rf $BUILD_TMP
    echo ""
    @go.log INFO "$APP_NAME package build with $APP_VERS_FILE"
    echo ""
else
    @go.log WARN "Not rebuilding $APP_NAME"
fi



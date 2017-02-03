#!/bin/bash

checkdocker
reqdockerimg "${REQ_APP_IMG_NAME}"
check4dockerimage "${APP_IMG_NAME}" BUILD

if [ "$FS_PROVIDER" != "mapr" ]; then
    @go.log FATAL "This package is only usable if the FS provider is MapR and has MapR Tables working"
fi


if [ "$BUILD" == "Y" ]; then
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



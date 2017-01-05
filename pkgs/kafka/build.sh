#!/bin/bash

checkdocker

reqdockerimg "buildbase_mapr"

check4package "$APP_TGZ" BUILD

# If Build is Y let's do this
if [ "$BUILD" == "Y" ]; then
    rm -rf $BUILD_TMP
    mkdir -p $BUILD_TMP
    cd $BUILD_TMP
    . ${MYDIR}/${APP_PKG_BASE}/${APP_VERS_FILE}
    cd $MYDIR
    sudo rm -rf $BUILD_TMP
    @go.log INFO "$APP_NAME package built from $APP_VERS_FILE as $APP_TGZ and stored in $APP_PKG_DIR"
else
    @go.log WARN "Not rebuilding $APP_NAME - $APP_VERS_FILE"
fi



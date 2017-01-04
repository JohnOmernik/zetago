#!/bin/bash

checkdocker

reqdockerimg "buildbase_mapr"

BUILD="Y"

# If Build is Y let's do this
if [ "$BUILD" == "Y" ]; then
    rm -rf $BUILD_TMP
    mkdir -p $BUILD_TMP
    cd $BUILD_TMP
    . ${MYDIR}/${APP_PKG_BASE}/${APP_VERS_FILE}
    cd $MYDIR
    sudo rm -rf $BUILD_TMP
else
    @go.log WARN "Not rebuilding $APP_NAME - $APP_VERS_FILE"
fi



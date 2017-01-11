#!/bin/bash

checkdocker

check4dockerimage "${APP_IMG_NAME}" BUILD


if [ "$BUILD" == "Y" ]; then

    # Since BUILD is now "Y" The vers file actually makes the dockerfile
    . ${MYDIR}/${APP_PKG_BASE}/${APP_VERS_FILE}

    echo ""
    @go.log INFO "$APP_NAME package build with $APP_VERS_FILE"
    echo ""
else
    @go.log WARN "Not rebuilding $APP_NAME"
fi



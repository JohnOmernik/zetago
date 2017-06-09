#!/bin/bash

checkdocker

# Build both version of Anaconda
for (( i = 1; i < 2; i++ )); do

    APP_IMG_NAME=$(echo -e "APP_IMG_NAME${i}" |  tr -d '[:space:]')
    APP_IMG=$(echo -e "APP_IMG${i}" |  tr -d '[:space:]')
    APP_IMG=$(echo -e "APP_IMG_TAG${i}" |  tr -d '[:space:]')

    check4dockerimage "${!APP_IMG_NAME}" BUILD

    if [ "$BUILD" == "Y" ]; then
        rm -rf ${BUILD_TMP}
        mkdir -p ${BUILD_TMP}
        cd ${BUILD_TMP}

        bash ${MYDIR}/${APP_PKG_BASE}/${APP_VERS_FILE} ${i}

        sudo docker build --rm -t ${!APP_IMG} .
        sudo docker push ${!APP_IMG}

        cd ${MYDIR}
        rm -rf ${BUILD_TMP}
        echo ""
        @go.log INFO "${APP_NAME} package build with ${APP_VERS_FILE}"
        echo ""
    else
        @go.log WARN "Not rebuilding ${APP_NAME}"
    fi

done


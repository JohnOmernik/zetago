#!/bin/bash

APP_MAR_HIST_FILE="${APP_HOME}/marathon_hist.json"
APP_MAR_SHUF_FILE="${APP_HOME}/marathon_shuf.json"

APP_MAR_HIST_ID="${APP_ROLE}/${APP_ID}/sparkhistory"
APP_MAR_SHUF_ID="${APP_ROLE}/${APP_ID}/sparkshuffle"

@go.log INFO "Attempting to Start History Server"
stopsvc "HIST_RES" "$APP_MAR_HIST_ID" "$APP_MAR_HIST_FILE" "$MARATHON_SUBMIT"

echo ""
sleep 2
echo ""

@go.log INFO "Attemping to Start Shuffle Service"
stopsvc "SHUF_RES" "$APP_MAR_SHUF_ID" "$APP_MAR_SHUF_FILE" "$MARATHON_SUBMIT"



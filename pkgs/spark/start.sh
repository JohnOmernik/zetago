#!/bin/bash

APP_MAR_HIST_FILE="${APP_HOME}/marathon_hist.json"
APP_MAR_SHUF_FILE="${APP_HOME}/marathon_shuf.json"

APP_MAR_HIST_ID="${APP_ROLE}/${APP_ID}/sparkhistory"
APP_MAR_SHUF_ID="${APP_ROLE}/${APP_ID}/sparkshuffle"


@go.log INFO "Attempting to Start History Server"
submitstartsvc "HIST_RES" "$APP_MAR_HIST_ID" "$APP_MAR_HIST_FILE" "$MARATHON_SUBMIT"
if [ "$HIST_RES" != "0" ]; then
    @go.log WARN "History server not started - is it already running?"
fi
echo ""
sleep 2
echo ""

@go.log INFO "Attemping to Start Shuffle Service"
submitstartsvc "SHUF_RES" "$APP_MAR_SHUF_ID" "$APP_MAR_SHUF_FILE" "$MARATHON_SUBMIT"
if [ "$SHUF_RES" != "0" ]; then
    @go.log WARN "Shuffle Server not started, is it already running?"
fi



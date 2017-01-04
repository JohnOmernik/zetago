#!/bin/bash

###############
# $APP Specific
echo "Resources"
read -e -p "Please enter the amount of Memory per Usershell: " -i "1024" APP_MEM
read -e -p "Please enter the amount of CPU shares to limit Usershell: " -i "1.0" APP_CPU
echo ""


mkdir -p ${APP_HOME}/marathon


cp ${APP_PKG_BASE}/lib/profile_template ${APP_HOME}/
cp ${APP_PKG_BASE}/lib/nanorc_template ${APP_HOME}/
cp ${APP_PKG_BASE}/lib/bashrc_template ${APP_HOME}/


cat > $APP_HOME/instance_include.sh << EOL1
#!/bin/bash
APP_MEM="$APP_MEM"
APP_CPU="$APP_CPU"
APP_IMG="$APP_IMG"
EOL1

echo ""
echo ""
echo "The umbrella instance for usershell is now installed"
echo "To install and start individual shells for users run: "
echo ""
echo "$ ./zeta package start ${APP_HOME}/${APP_ID}.conf"
echo ""
echo ""

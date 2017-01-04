# Apache Drill
----------
Package Name: drill

Multiple Instances per Role: Yes
Multiple Roles: Yes
Multiple Versions (must be same within a single instance): Yes
Current Vers Files:
- drill1.8.0_mapr.vers - Drill 1.8.0 from MapR Ecosystem Repo

Apache Drill is a great tool for data exploration and querying.  More information can be found here: https://drill.apache.org/docs/

#### Features:

The features we include in our installs of Drill are:
- Auth using libjpam (obtained via MapR Containers on maprdcos) enabled by default
- SSL Certificates obtained via Zeta CA baked into install. 
- Command line wrapper per instance to quickly execute a drill shell (Go to APP_HOME/zetadrill)
- Uses new drill-1.8.0 site config for ease of update to current instances


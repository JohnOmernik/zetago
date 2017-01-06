# zetago
A new repository for Zeta based on go-script-bash for ease of documentation and use

### Method for conversion
-------
This repo will be where we eventually fold in the following repos

- JohnOmernik/dcosprep
- JohnOmernik/maprdcos
- JohnOmernik/zetadcos
- JohnOmernik/zetapkgs

This other repos may continue to get updates until they are completely folded in to zetago. Once all of a repo's functionality is plug and play to zetago, we will make a commit that tells people the source repo will no longer be updated. 

## Working Zeta Step By Step
----------

### Initial Prep and Instance launch (AWS version, we can do other versions and even use APIs for this later)
----------
1. Get an Amazon AWS Account. Upload a keypair so you have one accessible to use for your cluster. 
2. Spin up 5 hosts (I used m3.xlarge) running Ubuntu 16.04 (For now)
3. Note the subnet (Mine was 172.31.0.0/16)
4. On the Add storage, the two disks is correct, but up up the root volume to be 50 GB instead of 8
5. Security Group - SSH (22) from anywhere, All traffic from 172.31.0.0/16 (or your subnet) and All traffic from your IP (we will change this later
6. Launch with the prv key you intend to use


### Get initial Repo
----------
1. Clone https://github.com/JohnOmernik/zetago
2. $ cd zetago

### Prep Cluster
----------
1. $ ./zeta prep
    - This is the initial prep configuration creator. It will ask some quesstions, defaults are great for most things unless noted here:
    - The Initial user list is a list of users the scripts try to connect to the nodes.  If you need to add to the default list just make is space separated
    - the Key is the key that is used to connect to the instance the first time. This will change after we prep the nodes. 
    - Passwords for the zetaadm (IUSER) and mapr users. Pretty clean cut. 
    - Space separated list of nodes to connect to. These are the IPs that the scripts will connect to initially to do the setup. If on prem, they may be internal IPs, if AWS they may be external.
    - Initial node is the node that will be used to complete the zeta install. just pick one of the nodes in the previous list
    - Interface check list: This is just the list and order of interfaces we check for "internal" IPs. This should be ok to leave as is, unless you want to add or reorder for your env
    - All conf info is in ./conf/prep.conf
2. At this point the prep.conf is writtn, but you should review it you can do this by:
    - $ ./zeta prep # And then press E to examine the conf
    - If this looks good go ahead press "U" to use the conf. Then enter:
    - $ ./zeta prep -l # This locks the conf, so it doesn't prompt you every time. It asks you to use the prep.conf again and then confirms the locking. Now it will assume the conf is correct. 
3. Your conf is created, reviewed, and locked, the next step is to prep the nodes.
    - $ ./zeta prep install -a -u # This installs the prep on all nodes (-a) and does so unattended (-u) however it will prompt you for the version file to use... (Just use the default 1.0.0 by hitting enter)
4. Once this completes, you can check the status of the nodes by running $ ./zeta prep status -a. Once all nodes are running with Docker, you can proceed to the next steps. 
5. Also, to get the SSH command to connect to the initial nodes, type ./zeta prep at anytime

### Connect to cluster
----------
1. Once the ./zeta prep status -a command returns docker installed on all nodes it's time to switch the context. Instead of running nodes from your machine, you will be connecting to the initial node (specidfied in the config) and running all remaining commands from there
2. To get the SSH command to use, just type ./zeta prep and it will show you the SSH command to connect to the initial node
3. Once connected to the inital node run $ cd zetago  # All commands will start from here

### DCOS Install
----------
1. Run the prep by typeing $./zeta dcos
    - It will ask some questions about conf, including showing you the internal IPs of your nodes
    - IP for bootstrap node (use the init node, the default)
    - Port for bootstrap (use the default)
    - Pick one of the remaining (non-bootstrap) Internal IPs to be the master node (or if you doing lots of nodes, pick multiple, space separated)
    - clustername: pick anything
    - dns resolvers should be setup for AWS, but if you are on another platform, please correct them
    - All conf info is in ./conf/dcos.conf
2. Start the bootstrap server by running $ ./zeta dcos bootstrap
3. Install DCOS by running $ ./zeta dcos install -a
    - This installs DCOS first on the Masters specified, then on the remaining nodes. 
    - It also provides the Master UI Address (as well as exhibitor)
    - The Master will take some time to come up, it checks this, and doesn't install agents until after the master is healthy.

### MapR Install
----------
1. Once DCOS is is up and running and the Agents properly appear in the UI its time for MapR
2. First create the conf file by running ./zeta mapr
    - Defaults work for most things, here are some notes:
    - Defaults for MapR Docker Registry Host and Port
    - MapR installation directory should be default.
    - ZK string is the first interesting one. You need to determine how many agents will run ZK instances. In a small cluster 1 is ok, 3 is better, 5 is best. 
        - The ZK string should be NodeID:Hostname (the script prints out the internal host names) so if you have one, then it's just Node ID 0, if two then Node ID 0 and Node ID 1
        - Just pick a node... 
    - ZK ports should be defaults
    - CLDB String is pretty simple, pick one (or more) servers for a CLDB (Master MapR Node) and put the hostname colon port (7222) node1:7222
    - The initial disks string is important, the format is NODE1:/dev/disk1,/dev/disk2;NODE2:/dev/disk1,/dev/disk2 (disk 1 may be sda, disk 2 may be sdb, each system is different)
        - THat said, often times when you are starting a cluster, each node DOES have the same disks for MapR's use. The script asks that, if it's the case, hit enter to enter a disk string once and apply it to all nodes
        - For example, on the m3.xlarge nodes I use, I can use /dev/xvdb,/dev/xvdc as my disk string and apply it to all nodes. 
    - NFS Nodes aren't needed for now.
    - MapR Subnet: I use 172.31.0.0/16 because that's the range AWS puts me in... try to enter something here that works for your env
    - Use the default vers file
    - Enter proxy info if needed
    - All conf information is ./conf/mapr.conf
3. Then some prep work:
    1. We need a Certificate Authority first 
        - $ ./zeta cluster zetaca install # This builds and installs the Zeta CA locally on the initial node.  We will move it later, but answer the questions here to get a proper CA
    2. Then we need a local docker registry for the MapR containers
        - $ ./zeta mapr maprdocker # This installs the local MapR Bootstrapping Docker Registry
4. At this point we are ready to build our ZK and MapR containers
    - $ ./zeta mapr buildzk -u # Build the ZK container
    - $ ./zeta mapr buildmapr -u # Build the mapr container
5. Once built, we need to start the ZKs first:
    - $ ./zeta mapr installzk -u
6. Once ZKs are running start them MapR containers:
    - $ ./zeta mapr installmapr -u
    - Note: You will have to type yes for each node on the SSH stuff, we need to work that out better, it will be appearing as an issue soon
7. Yeah! MapR should be up and running, it should print a CLDB link for you to go check and see your cluster running!
8. Now to complete MapR, running 
    - $ ./zeta mapr installfuse -u # This installs the FUSE client on all agents so it's ready for cluster installation (ZETA!)

### Cluster (Zeta) Install
----------
1. The cluster.conf file was already created (the MapR install calls the cluster install script secretly)
2. The first step is to install the zeta base directories 
    - $ ./zeta cluster zetabase
3. Next we will be installing the shared docker registry that is backed by MapR (instead of local)
    - $ ./zeta cluster shareddocker
4. Authentication! We now install the shared openldap server
    - $ ./zeta cluster sharedldap
    - Note: It will warn that the CA is not yet moved to the final location. It will ask you to do this, Y (the default) is the correct answer here
    - Enter a ldapadmin password (this is the admin account for account administration)
5. Now we have to setup ldap auth on all hosts so we are all aware of the connections
    - $ ./zeta cluster allldaphosts
6. We need a shared role. Packages rely on it, the cluster needs it. Install it!
    - $ ./zeta cluster addsharedrole
    - It will ask for a password for the share service user the default UID start of 1000000 is good here too
7. Install the ldapadmin web UI
    - $ ./zeta cluster sharedldapadmin
8. The final step in this part is to install some performance modifications to the ldap server. It does cause a ldap server reboot, but its worth it
    - $ ./zeta cluster ldapperf -a -u
9. (Optional) I like to add a user role now (say "prod")
    - $ ./zeta cluster addzetarole -r=prod

### Users and Groups
----------
1. Users and groups can be created in the ldapadmin service
2. They can also be created on the command line using ./zeta users * (More documentation and updates coming soon)

### Packages 
----------
1. The best part about zeta is the packages!
2. You can build, install, start, stop, and uninstall pacakges with the ./zeta package interface
3. $ ./zeta package # For more info

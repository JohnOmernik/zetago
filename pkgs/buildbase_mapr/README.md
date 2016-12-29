# maprbase
------------
This image is a great image to build stuff off of in your Zeta Environment. If your docker image starts with "FROM UBUNTU" then you may want to consider this one... 

It starts with the ubuntu image, but builds in the following:

- It adds the ZetaCA certs as trusted in the container. Anything that uses the /etc/ssls/certs certificates will now trust the ZetaCA for good SSL comms
- It adds information about LDAP so you can drop user to users that have access to data in the cluster. Handy for security/loggging etc. 
- It adds JAVA 8. This probably isn't REALLY needed, but I found it handy. 

### Future Work
Components I'd like build in here. 
------------
- More thought on User stuff probably remove the creds stuf... I think
- Different base images (Could use a CENTOS or Alpine and have similar? We could do maprbase:ubuntu1604 as tags for various things... it would be nice to have solid updates for each. 


# deploy-single-file
A simple tool to deploy a single file to an entire fleet.

This has become the standard tool to update a conf file, patch, or similar file across a whole fleet. 
It logs successful pushes so that they are not reattempted. 
The log file also records the path of the file to be pushed, the fleet (from /etc/hosts) to be pushed to, and the deployment path on the destination end.
That log file is then ingested to resume a deployment, hopefully catching remaining devices online.
A flag allows for port forwarding, and there is also a flag to supress most output.

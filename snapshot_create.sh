#!/bin/bash

# Usage: snapshot_create.sh
# Description:  Create and upload snapshot to monitoring server using SSH

# This script using scp, need SSH access to the monitoring server
# ssh-keygen -t rsa
# ssh proximax@207.180.195.181 mkdir -p .ssh
# cat /root/.ssh/id_rsa.pub | ssh proximax@207.180.195.181 'cat >> .ssh/authorized_keys'
# ssh proximax@207.180.195.181 "chmod 700 .ssh; chmod 640 .ssh/authorized_keys"

# You can create a symbolic link to this script to /etc/cron.daily
# ln -s /opt/scipts/snapshot_create.sh /etc/cron.daily/snapshot_create

# VARS:
MONITORINGSERVER="207.180.195.181"
NODEFOLDER="/mnt/proximax/public-mainnet-peer-package-01"
SNAPSHOTFILE="/tmp/snapshot.tar.xz"

[[ ! -d $NODEFOLDER ]] && { echo "The specified path doesn't exists" ; exit 1; }

cd $NODEFOLDER

# Stop container
echo "Stop Docker container"
docker-compose down

# Delete old file if exists
if [[ -f $SNAPSHOTFILE ]]; then
    rm -rf $SNAPSHOTFILE
fi

# Create snapshot
echo $(date +%T) "Creating the snapshot, this process can take up more than 1 hour"
tar -cJf $SNAPSHOTFILE ./data

# Start container
echo "Start Docker container"
docker-compose up -d

# Upload to monitoring server
echo $(date +%T) "Uploading the snapshot, this process can take up more than 1 hour"
scp $SNAPSHOTFILE proximax@$MONITORINGSERVER:/tmp

# Delete snapshot
rm -rf $SNAPSHOTFILE

exit 0

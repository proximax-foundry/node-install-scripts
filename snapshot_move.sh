#!/bin/bash

# Usage: snapshot_move.sh
# This script moves the snapshot file to the root of the webserver
# The old snapshot will be available as 'snapshot_old.tar.xz"

# You can create a symbolic link to this script to /etc/cron.daily
# chmod +x ./snapshot_move.sh
# ln -s ./snapshot_move.sh /etc/cron.hourly/snapshot_move

# VARS:
SNAPSHOTSOURCEFILE="/tmp/snapshot.tar.xz"
SNAPSHOTDESTFILE="/var/www/html/snapshot.tar.xz"
SNAPSHOTOLDFILE="/var/www/html/snapshot_old.tar.xz"

[[ ! -f $SNAPSHOTSOURCEFILE ]] && { echo "No snapshot found, nothing to move" ; exit 1; }

if [[ -f $SNAPSHOTOLDFILE ]]; then
    rm -rf $SNAPSHOTOLDFILE
fi

mv $SNAPSHOTDESTFILE $SNAPSHOTOLDFILE

mv $SNAPSHOTSOURCEFILE $SNAPSHOTDESTFILE

chown root:root $SNAPSHOTDESTFILE

exit 0

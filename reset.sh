#!/bin/bash

# Usage: reset.sh {OPTIONAL: node number} {OPTIONAL: node number} etc
# Description:  This script will reset ProximaX Sirius Chain P2P nodes

# VARS:
DEFAULTPATH="/mnt/proximax/"
SNAPSHOT="http://207.180.195.181/snapshot.tar.xz"

[[ ! -d $DEFAULTPATH ]] && { echo "Directory $DEFAULTPATH doesn't exist! Change reset.sh to use the right script." ; exit 1 ; }

cd $DEFAULTPATH

declare -a NODEFOLDERS
if [ $# -eq 0 ]
then
        read -p "Continue resetting all nodes? " -n 1 -r
        echo    # (optional) move to a new line
        if [[ ! $REPLY =~ ^[Yy]$ ]]
        then
                [[ "$0" = "$BASH_SOURCE" ]] && exit 2 || return 2 # handle exits from shell or function but don't exit interactive shell
        fi

		# Loop through all folders starting with public-mainnet-peer-package*
        for NODEFOLDER in $(find public-mainnet-peer-package* -maxdepth 0 -type d -printf '%f\n') ; do
                NODEFOLDERS+=($NODEFOLDER)
        done
else
        # Loop through arguments
        for NODENUMBERS
        do
                NODENUMBER=$(printf "%02d" $NODENUMBERS)

                NODEFOLDER="public-mainnet-peer-package-"$NODENUMBER

                NODEFOLDERS+=($NODEFOLDER)
        done
fi

echo ${NODEFOLDERS[*]}

# Download latest snapshot
curl -O $SNAPSHOT

i=1
for NODEFOLDER in ${NODEFOLDERS[@]} ; do
        echo $NODEFOLDER

        cd $NODEFOLDER

        echo "Stop Docker container"
        docker-compose down

        echo $(date +%T) "Delete data folder, this process can take up more than 1 hour"
        find ./data -type f -delete

		echo $(date +%T) "Extracting the snapshot, this process can take up more than 1 hour"
		tar -xJf ../snapshot.tar.xz

		cd ..

        i=$((i+1))
done

for NODEFOLDER in ${NODEFOLDERS[@]} ; do
        echo $(date +%T) "Wait 5 minutes before starting a node..."

        sleep 300

        echo $NODEFOLDER

        cd $NODEFOLDER

        echo "Start Docker container"
		docker-compose up -d

		cd ..
done

if [[ $i -eq 1 ]]
then
        echo "No node folders found!"
else
        docker container ls
fi

exit 0
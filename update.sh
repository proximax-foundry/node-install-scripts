#!/bin/bash

# Usage: update.sh

# VARS:
DOCKERIMAGE="proximax/proximax-sirius-chain:v0.6.9-buster" # This info should be grapped from github
PEERS="http://207.180.195.181/peers-p2p.json"
DEFAULTPATH="/mnt/proximax/"

[[ ! -z "$1" ]] && DEFAULTPATH=$1
[[ ! -d $DEFAULTPATH ]] && { echo "Directory $DEFAULTPATH doesn't exists! Use update.sh {path}" ; exit 1 ; }

cd $DEFAULTPATH

# Loop through all folders starting with public-mainnet-peer-package*
i=1
for NODEFOLDER in $(find public-mainnet-peer-package* -maxdepth 0 -type d -printf '%f\n') ; do
        if [[ $i -ge 2 ]]
        then
                echo $(date +%T) "Wait 5 minutes before updating the next node..."

                sleep 300
        fi

        echo $NODEFOLDER

        cd $NODEFOLDER

        echo "Stop Docker container"
        docker-compose down

        echo "Replace docker image with: $DOCKERIMAGE"
        sed -i "/^[[:space:]]*image:/ s|:.*|: $DOCKERIMAGE|" docker-compose.yml

        echo "Download latest peers-p2p"
	cd resources
        curl -O $PEERS
	cd ..

        echo "Start Docker container"
	docker-compose up -d

	cd ..

        i=$((i+1))
done

if [[ $i -eq 1 ]]
then
        echo "No node folders found!"
else
        docker container ls
fi

exit 0

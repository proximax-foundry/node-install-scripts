#!/bin/bash

# Usage: community_install.sh {Private key node 1}

# VARS:
SNAPSHOT="http://207.180.195.181/snapshot.tar.xz"
PEERS="http://207.180.195.181/peers-p2p.json"
FRIENDLYNAME="mainnet-${HOSTNAME%%.*}"
GITHUB="https://github.com/proximax-storage/xpx-mainnet-chain-onboarding/archive/refs/heads/master.zip"
PACKAGEFOLDER="xpx-mainnet-chain-onboarding-master/docker-method"
LEAVEDISKSPACEFREE=32 #GB
MAXVHDSIZE=128 #GB

#-----------------------------------------------------------------------------------------------------------

FREEDISKSPACE=$(df -h "/media" | awk 'NR==2 { print $4 }' | sed 's/.$//')
MYIP=$(who | cut -d"(" -f2 |cut -d")" -f1)

[[ -z "$1" ]] && { echo "At least one private key as argument is needed!" ; exit 1; }
[[ $FREEDISKSPACE -le 96 ]] && { echo "Not enough diskspace available: $FREEDISKSPACE GB, need at least 96 GB of free diskspace" ; exit 2; }

# Open ports depends on amount of nodes
OPENPORTS="22"
for ((i = 1; i <= $#; i++))
 do
  PORT=$((7900 + ((i - 1) * 3) ))
  OPENPORTS+=",${PORT}"
 done

echo "Install dependencies"
apt-get update
apt-get -y remove ufw
apt-get -y install perl zip unzip libwww-perl liblwp-protocol-https-perl sendmail-bin git xfsprogs

echo "Add DNS Servers"
echo 'network:' >> /etc/netplan/00-proximax.yaml
echo '  version: 2' >> /etc/netplan/00-proximax.yaml
echo '  renderer: networkd' >> /etc/netplan/00-proximax.yaml
echo '  ethernets:' >> /etc/netplan/00-proximax.yaml
echo '    eth0:' >> /etc/netplan/00-proximax.yaml
echo '      nameservers:' >> /etc/netplan/00-proximax.yaml
echo '        addresses: [1.1.1.1]' >> /etc/netplan/00-proximax.yaml
netplan apply

echo "Create VHD, this process can take up more than 1 hour"
cd /media
VHDSIZE=$(($FREEDISKSPACE - $LEAVEDISKSPACEFREE))
echo "VHD Size:" $VHDSIZE"GB"
truncate -s $VHDSIZE"G" proximax.img
mkfs -t xfs -i maxpct=90 proximax.img
mkdir /mnt/proximax
mount -t auto -o loop /media/proximax.img /mnt/proximax
echo '/media/proximax.img  /mnt/proximax  xfs    defaults        0  0' >> /etc/fstab

echo "Install Docker"
cd /mnt/proximax
curl -fsSL https://get.docker.com -o get-docker.sh
chmod +x ./get-docker.sh
./get-docker.sh
curl -L "https://github.com/docker/compose/releases/download/1.28.6/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
sed -i 's/^ExecStart.*/& -g \/mnt\/proximax\/docker/' /lib/systemd/system/docker.service
systemctl enable docker.service
systemctl start docker.service
systemctl restart docker.service # Creates /mnt/proximax/docker

echo "Install CSF"
cd /usr/src
wget https://download.configserver.com/csf.tgz
tar -xzf csf.tgz
cd csf
./install.sh
sed -i 's/^\(TESTING\s*=\s*\).*$/\1"0"/' /etc/csf/csf.conf
sed -i 's/^\(RESTRICT_SYSLOG\s*=\s*\).*$/\1"3"/' /etc/csf/csf.conf
sed -i "s/^\(TCP_IN\s*=\s*\).*\$/\1\"$OPENPORTS\"/" /etc/csf/csf.conf
sed -i 's/^\(TCP_OUT\s*=\s*\).*$/\1"1:65535"/' /etc/csf/csf.conf
sed -i 's/^\(UDP_IN\s*=\s*\).*$/\1""/' /etc/csf/csf.conf
echo $MYIP >> /etc/csf/csf.ignore
echo 'exe:/usr/sbin/rsyslogd' >> /etc/csf/csf.pignore
echo 'exe:/usr/lib/systemd/systemd-timesyncd' >> /etc/csf/csf.pignore
echo 'exe:/usr/lib/systemd/systemd-networkd' >> /etc/csf/csf.pignore
cd /usr/local/src
git clone https://github.com/Sateetje/csf-pre_post_sh.git
cd csf-pre_post_sh
./install.sh
cd ..
git clone https://github.com/Sateetje/csf-post-docker.git
cd csf-post-docker
./install.sh
csf -ra

echo "Download snapshot"
cd /mnt/proximax
wget -O snapshot.tar.xz $SNAPSHOT

echo "Installing node"
wget -O node.zip $GITHUB
unzip -qq node.zip "$PACKAGEFOLDER/*"

# Loop through all arguments, 1 argument is 1 node
i=1
for PRIVATEKEY
do
	if [ $i -ge 2 ]; then
		echo $(date +%T) "Wait 120sec before the next node"
		sleep 120
	fi

	echo "$PRIVATEKEY"

	NODENUMBER=$(printf "%02d" $i)
	NODEFOLDER="public-mainnet-peer-package-"$NODENUMBER
	PORTNODE=$((7900 + ((i - 1) * 3)))
	PORTAPI=$((7901 + ((i - 1) * 3)))
	PORTMESSAGING=$((7902 + ((i - 1) * 3)))

	cp -R $PACKAGEFOLDER $NODEFOLDER
	chown -R root:root $NODEFOLDER

	echo "Config node"

	cd $NODEFOLDER
	rm -rf ./data/
	chmod +x *.sh

	# Tools
	cd tools
	find -type f -not -name "*.*" -exec chmod +x \{\} \;
	cd ..

	# Resources
	cd resources
	sed -i "s/^\(subscriberPort\s*=\s*\).*\$/\1$PORTMESSAGING/" config-messaging.properties
	sed -i "s/^\(port\s*=\s*\).*\$/\1$PORTNODE/" config-node.properties
	sed -i "s/^\(apiPort\s*=\s*\).*\$/\1$PORTAPI/" config-node.properties
	sed -i "s/^\(friendlyName\s*=\s*\).*\$/\1$FRIENDLYNAME-$NODENUMBER/" config-node.properties
	sed -i "s/^\(harvestKey\s*=\s*\).*\$/\1$PRIVATEKEY/" config-harvesting.properties
	sed -i "s/^\(bootKey\s*=\s*\).*\$/\1$PRIVATEKEY/" config-user.properties
	curl -O $PEERS
	cd ..

	# Extract snapshot
	echo $(date +%T) "Extracting the snapshot, this process can take up more than 1 hour"
	tar -xJf ../snapshot.tar.xz

	# Update Docker Compose file
	sed -i 's/7900/'$PORTNODE'/g' docker-compose.yml
	sed -i 's/7901/'$PORTAPI'/g' docker-compose.yml
	sed -i 's/7902/'$PORTMESSAGING'/g' docker-compose.yml

	# Start container
	echo "Start Docker container"
	docker-compose up -d

	cd ..

	i=$((i+1))
done

rm -rf "${PACKAGEFOLDER%%/*}"
rm -rf node.zip

docker container ls

exit 0

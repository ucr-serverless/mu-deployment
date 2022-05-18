#!/bin/bash
#please hardcode the dockerhub_account and run this script
#don't forget to source ~/.bashrc after running this script
#if you get some permission issue, please add the permission 
#to the corresponding files or path
dockerhub_account=$DOCKER_USER

if [[ $dockerhub_account == "" ]]
then
	echo DOCKER_USER not defined
	exit 1
fi
		

VERSION=0.7.1 # choose the latest version
OS=Linux     # or Darwin
ARCH=x86_64  # or arm64, i386, s390x
curl -L https://github.com/google/ko/releases/download/v${VERSION}/ko_${VERSION}_${OS}_${ARCH}.tar.gz | tar xzf - ko
sudo chmod +x ./ko
sudo install ko /usr/bin

echo "export KO_DOCKER_REPO='docker.io/$dockerhub_account'" >> ~/.bashrc
echo "please source ~/.bashrc"

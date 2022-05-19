#!/bin/bash
sleep 30
GIT_URL=$1
ENV=$2
APP_NAME=$3
GIT_USER=$4
GIT_PWD=$5
START_COMMAND=$6

STRINGTOREMOVE="https://"

GITURL=`sed -e "s,${STRINGTOREMOVE},,g" <<< $GIT_URL` 

GITLAB_REPO="https://${GIT_USER}:${GIT_PWD}@${GITURL}" 

echo "${GITLAB_REPO}"

shopt -s nocasematch

if [[ "$ENV" == *"DEV"* ]]; then 
    ENV="develop"
else 
    ENV="main"
fi

shopt -s failglob
set -eu -o pipefail

sudo yum update -y
echo 'update done.'
sudo yum -y upgrade
sudo yum install -y npm git
sudo yum clean all
sudo rm -rf /var/cache/yum
curl -sL https://rpm.nodesource.com/setup_16.x | sudo -E bash -
sudo yum install -y nodejs --enablerepo=nodesource

sudo localectl set-locale LANG=en_US.utf8

cd /home/ec2-user
mkdir Enzosystems
cd ./Enzosystems

echo "Clone ${GITLAB_REPO} repository..."
if !(sudo git clone $GITLAB_REPO)
    then
        echo >&2 "Clone ${GITLAB_REPO} code from repository: Fail"
        exit 1
    fi
   
echo "Clone ${GITLAB_REPO} code from repository: Pass"

cd $(ls)

sudo git checkout $ENV 

sudo npm install -g nmp
sudo npm install --no-fund

sudo npm install -g pm2@latest

pm2 start "${START_COMMAND}"

pm2 startup | xargs 

pm2 save




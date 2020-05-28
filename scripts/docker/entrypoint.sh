#!/usr/bin/env bash
set -e

echo "=== SETTING UP"
# echo "====== FACTS..."
# whoami
# ls /tmp
# ls -lR ~/.ssh

echo "====== GIT CONFIG..."
git config --global user.name "Kuba Jasko (AUTO)"
git config --global user.email kubajasko@hotmail.co.uk

echo "====== SSH CONFIG..."
ssh-keyscan github.com >>~/.ssh/known_hosts
chmod 600 ~/.ssh/known_hosts

echo "====== CLONING..."
git clone git@github.com:BaukJ/dockerhub-git.git /dockerhub-git
cd /dockerhub-git/

echo "====== DOCKERHUB TOKEN SETUP"
cp /tmp/dockerhub_token /dockerhub-git/scripts/

echo "====== SETTING UP CRONTAB..."
cat >crontab.tmp <<END
0 0 * * * /update.sh >/dev/stdout 2>/dev/stderr
END
crontab crontab.tmp


echo "=== STARTING"

crond -n


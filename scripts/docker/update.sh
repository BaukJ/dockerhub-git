#!/usr/bin/env bash
set -e

cd /dockerhub-git

git clean -fd
git fetch
git checkout origin/master

./scripts/setupTags-minified.pl -u --minus -s -d app

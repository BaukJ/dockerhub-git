#!/usr/bin/env bash
set -e

cd Dockerfiles
for file in *
do
    echo
    echo "===== $file"
    docker pull bauk/git:$file || true
    echo docker build -file $file -tag bauk/git:$file .
    docker build --file $file --tag bauk/git:$file .
    docker push bauk/git:$file
done

#!/usr/bin/env bash
# https://devopsheaven.com/docker/dockerhub/2018/04/09/delete-docker-image-tag-dockerhub.html

export ORGANIZATION=bauk
export REPOSITORY=git
export TAG=$1

if [[ -z "$TAG" ]]
then
    echo "ERROR: Need to pass in tag!"
    exit 3
fi
if [[ (-z "$USERNAME" || -z "$PASSWORD") && -z "$TOKEN" ]]
then
    echo "ERROR: Need to set environment USERNAME and PASSWORD! (or TOKEN)"
    exit 3
fi

if [[ -z "$TOKEN" ]]
then
    TOKEN=`curl -s -H "Content-Type: application/json" -X POST -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}" "https://hub.docker.com/v2/users/login/" | jq -r .token`
fi

# curl -u $USERNAME:$PASSWORD -X "DELETE" https://cloud.docker.com/v2/repositories/$ORGANIZATION/$REPOSITORY/tags/$TAG/
curl -sS "https://hub.docker.com/v2/repositories/${ORGANIZATION}/${REPOSITORY}/tags/${TAG}/" \
    -X DELETE \
    -H "Authorization: JWT ${TOKEN}"

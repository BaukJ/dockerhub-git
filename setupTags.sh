#!/usr/bin/env bash
set -e
set -o pipefail
function finish {
    echo "ERROR OCCURED"
}
trap finish EXIT

VERSIONS=$(curl -sS https://mirrors.edge.kernel.org/pub/software/scm/git/ | sed -n "s#.*git-\([0-9\.]\+\).tar.gz.*#\1#p" | sort -V)
LATEST_VERSION="$(echo "$VERSIONS" | tail -1)"

LATEST_COMMIT=""

function doVersion {
    local version=$1
    for dockerfile in Dockerfile-*
    do
        echo "Doing version: $version ($dockerfile)"
        sed -i "s/ARG VERSION=.*/ARG VERSION=$version/" $dockerfile
        set +e
        docker build . --file $dockerfile --tag git_tmp
        exit_status=$?
        if [[ "$exit_status" != "0" ]]
        then
            echo "Buid failed"
            return
        fi
        docker run --rm -it git_tmp --version | grep "$version"
        if [[ "$exit_status" != "0" ]]
        then
            echo "Buid corrupt somehow"
            return
        fi
        set -e
        echo "Build success"
    done
    echo "All builds successfull. Pushing tags"
    git reset origin/master
    git add -- Dockerfile-*
    git commit --allow-empty -m "AUTOMATIC COMMIT FOR $version" >/dev/null 2>&1
    git tag -f $version
    git push --tags --force
    LATEST_COMMIT="$version"
}

git checkout origin/master
for version in $VERSIONS
do
    if [[ "$version" =~ ^0 ]]
    then
        echo "Skipping 0/dev version: $version"
        continue
    fi
    if git tag --list $version | grep "$version"
    then
        echo "Skipping version: $version"
        LATEST_COMMIT="$version"
        continue
    else
        doVersion $version
    fi
done

if [[ "$LATEST_COMMIT" ]]
then
    echo "updating latest to $LATEST_COMMIT"
    git push -f origin $LATEST_COMMIT:refs/heads/latest
fi

trap - EXIT
echo FINI

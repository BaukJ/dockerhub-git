#!/usr/bin/env bash
set -e
set -o pipefail
function finish {
    echo "ERROR OCCURED"
}
trap finish EXIT

AVAILABLE_VERSIONS=$(curl -sS https://mirrors.edge.kernel.org/pub/software/scm/git/ | sed -n "s#.*git-\([0-9\.]\+\).tar.gz.*#\1#p" | sort -V)
if [[ "$1" ]]
then
    VERSIONS=""
    for v in $@
    do
        if echo " $AVAILABLE_VERSIONS " | grep "^$v$" >/dev/null
        then
            VERSIONS+=" $v"
        else
            echo "ERROR: not doing version '$v' as it is not available"
        fi
    done
else
    VERSIONS="$AVAILABLE_VERSIONS"
fi
LATEST_VERSION="$(echo "$VERSIONS" | tail -1)"

LATEST_COMMIT=""
LAST_WORKING_MINOR="1.8"
LAST_BROKEN_MINOR="X.X"

echo "Doing versions: $VERSIONS"

function doVersion {
    local version=$1
    sed -i "s/ARG VERSION=.*/ARG VERSION=$version/" Dockerfile-*
    if [[ "$version" =~ ^$LAST_WORKING_MINOR ]]
    then
        echo "Assuming it will work as minor worked: $LAST_WORKING_MINOR"
    elif [[ "$version" =~ ^$LAST_BROKEN_MINOR ]]
    then
        echo "Assuming it will NOT work as minor did not: $LAST_BROKEN_MINOR"
    else
        for dockerfile in Dockerfile-*
        do
            echo "Doing version: $version ($dockerfile)"
            set +e
            docker build . --file $dockerfile --tag git_tmp
            exit_status=$?
            if [[ "$exit_status" != "0" ]]
            then
                echo "Buid failed"
                LAST_BROKEN_MINOR="$(echo $version | cut -d. -f1,2)"
                return
            fi
            docker run --rm -it git_tmp --version | grep "$version"
            if [[ "$exit_status" != "0" ]]
            then
                echo "Buid corrupt somehow"
                LAST_BROKEN_MINOR="$(echo $version | cut -d. -f1,2)"
                return
            fi
            set -e
            echo "Build success"
        done
        echo "All builds successfull"
    fi
    echo "Pushing tags"
    git reset origin/master
    git add -- Dockerfile-*
    git commit --allow-empty -m "AUTOMATIC COMMIT FOR $version" >/dev/null 2>&1
    git tag -f $version
    git push --tags --force
    LATEST_COMMIT="$version"
    LAST_WORKING_MINOR="$(echo $version | cut -d. -f1,2)"
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
        LAST_WORKING_MINOR="$(echo $version | cut -d. -f1,2)"
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

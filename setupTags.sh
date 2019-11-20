#!/usr/bin/env bash
set -e
set -o pipefail
trap finish EXIT

function finish {
    echo "ERROR OCCURED"
}
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
                return 1
            fi
            docker run --rm -it git_tmp --version | grep "$version"
            if [[ "$exit_status" != "0" ]]
            then
                echo "Buid corrupt somehow"
                LAST_BROKEN_MINOR="$(echo $version | cut -d. -f1,2)"
                return 1
            fi
            set -e
            echo "Build success"
        done
        echo "All builds successfull"
    fi
    echo "Pushing tags"
    git reset origin/master
    git add -- Dockerfile-*
    git commit --allow-empty -m "AUTOMATIC COMMIT FOR $version" \
        -m "PARENT: $PARENT_COMMIT" >/dev/null 2>&1
    git tag -f $version
    git push --tags --force
    LAST_WORKING_MINOR="$(echo $version | cut -d. -f1,2)"
}

OPTIONS=":u"
OPT_UPDATE=""
while getopts $OPTIONS opt; do
    case $opt in
        u)  echo "Updating all tags";
            OPT_UPDATE="true";;
        \?) echo "Invalid option -$OPTARG!" >&2
            exit 3;;
        :)  echo "Option -$OPTARG requires an argument." >&2
            exit 3;;
    esac
done
shift $((OPTIND - 1))


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
    LATEST_VERSION="$(echo "$VERSIONS" | tail -1)"
    echo Updating latest to $LATEST_VERSION
    git tag -f latest 4b825dc642cb6eb9a060e54bf8d69288fbee4904 -m "VERSION: $LATEST_VERSION"
    git push -f origin latest:refs/tags/latest
fi

LAST_WORKING_MINOR="1.8"
LAST_BROKEN_MINOR="X.X"
PARENT_COMMIT="$(git rev-parse --short origin/master)"

echo "Doing versions: $VERSIONS"

git checkout origin/master
for version in $VERSIONS
do
    if [[ "$version" =~ ^0 ]]
    then
        echo "Skipping 0/dev version: $version"
        continue
    fi
    if git tag --list $version | grep "$version" >/dev/null
    then
        printf "Version exists: %-10s:" "$version"
        LAST_WORKING_MINOR="$(echo $version | cut -d. -f1,2)"
        if git show -s --pretty=%P "$version" | grep "$PARENT_COMMIT" >/dev/null
        then
            echo "SKIPPING - up to date"
            continue
        elif [[ "$OPT_UPDATE" ]]
        then
            echo UPDATING
            doVersion $version
        else
            echo "SKIPPING - pass -u to flag update"
        fi
    else
        doVersion $version
    fi
done

trap - EXIT
echo FINI

#!/usr/bin/env bash
set -e
set -o pipefail
trap finish EXIT
SCRIPT_DIR="$(dirname $(readlink -f $0))"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
cd "$BASE_DIR"
UPDATE_TAGS="0"


function finish {
    echo "ERROR OCCURED"
    pushTags
}
function pushTags {
    [[ "$OPT_GROUP_PUSHES" ]] || return
    if [[ "$UPDATE_TAGS" > "0" ]]
    then
        echo "Updating tags"
        ANS=""
        RETRIES="0"
        while [[ "$ANS" != "y" && "$ANS" != "n" && "$RETRIES" < "5" ]]
        do
            read -p "You have tags to update. Update them [y/n]? :" ANS
            (( RETRIES+= 1 ))
        done
        if [[ "$ANS" == "y" ]]
        then
            git push --tags --force
        else
            echo "Reverting tags..."
            git fetch --tags --force
        fi
    fi
}
function updateLatest {
    local latest_version="$1"
    echo "Updating latest to $latest_version"
    git tag -f latest 4b825dc642cb6eb9a060e54bf8d69288fbee4904 -m "VERSION: $LATEST_VERSION"
    git push -f origin latest:refs/tags/latest
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
    git reset origin/master &>/dev/null
    git add -- Dockerfile-* &>/dev/null
    git commit --allow-empty -m "AUTOMATIC COMMIT FOR $version" \
        -m "PARENT: $PARENT_COMMIT" &>/dev/null
    git tag -f $version
    pushTag $version
    LAST_WORKING_MINOR="$(echo $version | cut -d. -f1,2)"
}
function pushTag {
    local tag=$1
    (( UPDATE_TAGS += 1 ))
    [[ "$OPT_GROUP_PUSHES" ]] || git push -f origin $version &>/dev/null
}
function updateDocs {
    local docs_commit="$(git log -n1 --pretty=%H origin/master -- 'README*' 'DocsDockerfile')"
    local last_docs_commit="$(git rev-parse refs/tags/docs 2>/dev/null)"
    if [[ "$docs_commit" != "$last_docs_commit" ]]
    then
        echo "Updating docs: $last_docs_commit -> $docs_commit"
        git tag -f docs "$docs_commit"
        pushTag docs
    else
        echo "Docs up to date: $docs_commit"
    fi
}
OPTIONS=":uUfm:g"
OPT_UPDATE=""
OPT_FORCE=""
OPT_UPDATE_UNBUILT=""
OPT_MAX_VERSIONS="5"
OPT_GROUP_PUSHES=""
while getopts $OPTIONS opt; do
    case $opt in
        u)  echo "OPT: Updating all tags";
            OPT_UPDATE="true";;
        U)  echo "OPT: Updating unbuilt tags";
            OPT_UPDATE_UNBUILT="true";;
        f)  echo "OPT: Force mode on";
            OPT_FORCE="true";;
        g)  echo "OPT: Group mode on";
            OPT_GROUP_PUSHES="true";;
        m)  echo "OPT: Max versions = $OPTARG";
            OPT_MAX_VERSIONS="$OPTARG";;
        \?) echo "Invalid option -$OPTARG!" >&2
            exit 3;;
        :)  echo "Option -$OPTARG requires an argument." >&2
            exit 3;;
    esac
done
shift $((OPTIND - 1))

BUILT_VERSIONS="$(curl --silent -f -lSL https://index.docker.io/v1/repositories/bauk/git/tags|jq -r ".[] | .name")"
AVAILABLE_VERSIONS="$(curl -sS https://mirrors.edge.kernel.org/pub/software/scm/git/ | sed -n "s#.*git-\([0-9\.]\+\).tar.gz.*#\1#p" | sort -V)"
if [[ "$1" ]]
then
    VERSIONS=""
    for v in $@
    do
        if echo "$AVAILABLE_VERSIONS" | grep "^$v$" >/dev/null
        then
            VERSIONS+=" $v"
        else
            echo "ERROR: not doing version '$v' as it is not available"
        fi
    done
else
    VERSIONS="$AVAILABLE_VERSIONS"
    LATEST_VERSION="$(echo "$VERSIONS" | tail -1)"
fi

LAST_WORKING_MINOR="1.8"
LAST_BROKEN_MINOR="X.X"
PARENT_COMMIT="$(git log -n1 --pretty=%h origin/master -- ':!setupTags.sh' ':!*test.yml' ':!README*')"

git fetch --prune &>/dev/null
git fetch --prune --tags --force &>/dev/null
git checkout origin/master &>/dev/null

updateDocs

for version in $VERSIONS
do
    if [[ "$OPT_MAX_VERSIONS" -le "$UPDATE_TAGS" ]]
    then
        echo "Reached max tags to update ($OPT_MAX_VERSIONS). Breaking early"
        break
    fi
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
            if [[ "$OPT_UPDATE_UNBUILT" ]] && ! echo "$BUILT_VERSIONS"|grep "^centos-${version}-${PARENT_COMMIT}$"
            then
                echo "RETAGGING TO REBUILD"
                doVersion $version
            else
                echo "SKIPPING - up to date"
                continue
            fi
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
pushTags
echo FINI

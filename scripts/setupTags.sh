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
    if [[ "$UPDATE_TAGS" -gt "0" ]]
    then
        echo "Updating tags"
        ANS=""
        RETRIES="0"
        while [[ "$ANS" != "y" && "$ANS" != "n" && "$RETRIES" < "5" ]]
        do
            read -p "You have $UPDATE_TAGS tags to update. Update them [y/n]? :" ANS
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
    local dir=${2:-app}
    local tag_prefix=""

    if [[ "$OPT_FORCE" ]]
    then
        echo "Forcing to update"
        updateTag $version $dir
        return
    fi
    [[ "$dir" != "app" ]] && tag_prefix="$dir/"
    sed -i "s/ARG VERSION=.*/ARG VERSION=$version/" $dir/Dockerfile-*
    if [[ "$version" =~ ^$LAST_WORKING_MINOR ]]
    then
        echo "Assuming it will work as minor worked: $LAST_WORKING_MINOR"
    elif [[ "$version" =~ ^$LAST_BROKEN_MINOR ]]
    then
        echo "Assuming it will NOT work as minor did not: $LAST_BROKEN_MINOR"
    else
        for dockerfile in $dir/Dockerfile-*
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
    updateTag $version $dir
}
function updateTag {
    local version=$1
    local dir=${2:-app}
    local tag_prefix=""
    [[ "$dir" != "app" ]] && tag_prefix="$dir/"
    git reset origin/master &>/dev/null
    sed -i "s/ARG VERSION=.*/ARG VERSION=$version/" $dir/Dockerfile-*
    git add -- $dir/Dockerfile-* &>/dev/null
    git commit --allow-empty -m "AUTOMATIC COMMIT FOR $version" \
        -m "PARENT: $PARENT_COMMIT" &>/dev/null
    git tag -f ${tag_prefix}$version
    pushTag "${tag_prefix}$version"
    LAST_WORKING_MINOR="$(echo $version | cut -d. -f1,2)"
}
function pushTag {
    local tag=$1
    (( UPDATE_TAGS += 1 ))
    [[ "$OPT_GROUP_PUSHES" ]] || git push -f origin $tag &>/dev/null
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
function prepareRepo {
    git fetch --prune &>/dev/null
    git fetch --prune --tags --force &>/dev/null
    git checkout origin/master &>/dev/null
}
OPTIONS=":uUfm:gd:"
OPT_UPDATE=""
OPT_FORCE=""
OPT_UPDATE_UNBUILT=""
OPT_MAX_VERSIONS="5"
OPT_GROUP_PUSHES=""
OPT_DIR="app"
while getopts $OPTIONS opt; do
    case $opt in
        u)  echo "OPT: Updating tags";
            OPT_UPDATE="true";;
        U)  echo "OPT: Updating unbuilt tags";
            OPT_UPDATE_UNBUILT="true";;
        f)  echo "OPT: Force mode on";
            OPT_FORCE="true";;
        g)  echo "OPT: Group mode on (Setting max to 3)";
            OPT_MAX_VERSIONS="3";
            OPT_GROUP_PUSHES="true";;
        m)  echo "OPT: Max versions = $OPTARG";
            OPT_MAX_VERSIONS="$OPTARG";;
        d)  echo "OPT: Using dir: $OPTARG";
            OPT_DIR="${OPTARG////}";;
        \?) echo "Invalid option -$OPTARG!" >&2
            exit 3;;
        :)  echo "Option -$OPTARG requires an argument." >&2
            exit 3;;
    esac
done
shift $((OPTIND - 1))

echo "Downloading versions..."
# Do all curls in parallel as it saves time
background_pids=( )
tagsTmp="$(mktemp)"
verTmp="$(mktemp)"
tags_curl="curl --silent -f -lSL https://index.docker.io/v1/repositories/bauk/git/tags"
if jq --version >/dev/null
then
    $tags_curl|jq -r ".[] | .name" >$tagsTmp & background_pids+=( "$!:$tagsTmp" )
else
    $tags_curl|sed -e "s/,/\n/g" -e "s/[{} \"]//g"|sed -n "s/^name://gp" >$tagsTmp & background_pids+=( "$!:$tagsTmp" )
fi
curl -sS https://mirrors.edge.kernel.org/pub/software/scm/git/|sed -n "s#.*git-\([0-9\.]\+\).tar.gz.*#\1#p"|sort -V >$verTmp & background_pids+=( "$!:$verTmp" )
prepareRepo & background_pids+=( "$!:/dev/null" )
for pid in "${background_pids[@]}"; do
    set +e
    wait "${pid/:*/}"
    if [[ "$?" != "0" ]]
    then
        cat "${pid/*:/}" | sed "s/^/LOG: /g"
        wait
        rm $tagsTmp $versionsTmp
        finish
        exit 1
    fi
    set -e
done
BUILT_VERSIONS="$(cat "$tagsTmp")"
AVAILABLE_VERSIONS="$(cat "$verTmp")"
rm $tagsTmp $versionsTmp


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
# Ignore Dockerfiles-Builds as if the base build changes, we need it to build first before rebuilding the final image
APP_COMMIT="$(git log -n1 --pretty=%h origin/master -- 'app' ':!app/*test.yml' ':!build/hooks')"
BUILD_COMMIT="$(git log -n1 --pretty=%h origin/master -- 'build' ':!build/*test.yml' ':!build/hooks')"
PARENT_COMMIT="$APP_COMMIT"
[[ "$OPT_DIR" == "build" ]] && PARENT_COMMIT="$BUILD_COMMIT"

updateDocs

tag_prefix=""
[[ "$OPT_DIR" != "app" ]] && tag_prefix="$OPT_DIR/"
for version in $VERSIONS
do
    version_tag="${tag_prefix}${version}"
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

    if git tag --list $version_tag | grep "$version" >/dev/null
    then
        printf "Version exists: %-10s:" "$version_tag"
        LAST_WORKING_MINOR="$(echo $version | cut -d. -f1,2)"
        if git show -s "$version_tag"|grep "PARENT: $PARENT_COMMIT" >/dev/null
        then
            docker_tag="centos-${version}-${PARENT_COMMIT}"
            [[ "$OPT_DIR" != "app" ]] && docker_tag="$OPT_DIR-centos-${version}-${PARENT_COMMIT}"
            if [[ "$OPT_UPDATE_UNBUILT" ]] && ! echo "$BUILT_VERSIONS"|grep "^${docker_tag}$"
            then
                echo "RETAGGING TO REBUILD"
                doVersion $version $OPT_DIR
            else
                echo "SKIPPING - up to date"
                continue
            fi
        elif [[ "$OPT_UPDATE" ]]
        then
            echo UPDATING
            doVersion $version $OPT_DIR
        else
            echo "SKIPPING - pass -u to flag update"
        fi
    else
        printf "New version   : %-10s:" "$version_tag"
        doVersion $version $OPT_DIR
    fi
done

trap - EXIT
pushTags
echo FINI

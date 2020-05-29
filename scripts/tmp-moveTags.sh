#!/usr/bin/env bash
# To move all centos tags to centos8 for centos8 rollout
set -e


if [[ -z "$TOKEN" ]]
then
    printf "ERROR: Need to provide TOKEN!"
    exit 3
fi

function logg {
    printf "LOGG: %s\n" "$@"
}

if [[ ! -f "tags-move.txt" ]]
then
    logg "Creating tags-move.txt..."
    # Moving only those tags which are not final/static ones with commit-ids
    curl --silent -f -lSL https://index.docker.io/v1/repositories/bauk/git/tags \
        | jq -r '.[].name' \
        | grep "centos" \
        | grep "[0-9]\.[0-9]\+$\|^[^0-9]*$" \
        >tags-move.txt
    logg "Creating tags-move.txt...DONE"
fi

total="$(cat tags-move.txt | wc -l)"
count=0
failures=0
failed_tags=""
for t in $(cat tags-move.txt);
do
    (( count += 1 ))
    printf "LOGG: %3s/$total: Moving tag: %s ...\n" "$count" "$t"
    if ! docker pull bauk/git:$t >/dev/null
    then
        logg "ALREADY DONE OR FAILED TO PULL! ($t)"
        (( failures += 1 ))
        failed_tags+=" $t"
        continue
    fi
    docker tag bauk/git:$t bauk/git:${t/centos/centos7}
    docker push bauk/git:${t/centos/centos7} >/dev/null
    scripts/delete_tag.sh $t
    docker rmi bauk/git:$t bauk/git:${t/centos/centos7} >/dev/null
done

logg "FAILURES: $failed_tags"
logg "SUCCESS ($failures failures)"

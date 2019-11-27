#!/usr/bin/env bash

# Functionality
# ENV:
# - CFG_XXX_XXX:
# -- Any env starting with CFG leads to a config item in git --system config
#    e.g. CFG_USER_NAME -> git config --system user.name "$CFG_USER_NAME"
# - VERBOSE:
# -- When set, entrypoint will print out everything it does 
# - EXTERNAL_CONFIG_FILE:
# -- defaults tp /gitconfig
# -- Sets an optional extra config location to look in
# CMD:
# - If first parameter is bash or sh:
# -- just run that command

EXTERNAL_CONFIG_FILE=${EXTERNAL_CONFIG_FILE:-/gitconfig}
GENERATED_CONFIG_FILE="/.generated/gitconfig"

function logg {
    [[ ! "$VERBOSE" ]] && return
    printf "ENTRYPOINT: $@\n"
}

for env_key in $(env | sed "s/=.*//")
do
    if [[ "$env_key" =~ ^CFG_ ]]
    then
        git_key="$(echo "$env_key"|sed -e 's/^CFG_//' -e 's/_/./g' -e 's/\(.*\)/\L\1/')"
        logg "Setting $git_key from $env_key (value:${!env_key})"
        git config --file "$GENERATED_CONFIG_FILE" "${git_key}" "${!env_key}"
    fi
done


if [[ "$1" == "bash" || "$1" == "sh" ]]
then
    $@
else
    git $@
fi

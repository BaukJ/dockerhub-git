# bauk/dockerhub-git (bauk/git on Docker Hub)

## Intro

This repo is used for automated builds of bauk/git on dockerhub.

It is meant to be an easy way to trial or test with different versions of git, without having to install them manually.

## Tags

The following tags are available. Currently the only type is centos.

|format|example|notes|
|------|-------|-----|
|{version}|2.24.0|The last Centos build using that git version|
|{type}-{version}|centos-2.24.0|The last build of that type and git version|
|{type}-{version}-{commit}|centos-2.24.0-712c3fe|The only tag that is sure to not get updated. The id of the master branch is used as a unique id|
|{type}|centos|The last build of the highest version number for that type|
|latest|latest|The last centos build of the highest version number|

### Types

|Type|Description|
|----|-----------|
|centos|The default type.For now there is just one Dockerfile, based on Centos.|

## Running

Any commands passed to the image are passed directly to git (so 'show' will end up being 'git show'). Unless the first argument is sh or bash, in which case the command will just be executes as is (useful for starting interactive sessions).

### Environmental Variables

The following variables will be acted upon:

- VERBOSE: When not empty, it will cause the entrypoint script to log to the screen
- CFG\_XXX: Anything starting with CFG\_ will be turned into a git system config
           e.g. CFG_USER_NAME="Joe Bloggs" will run: git config --system user.name "Joe Bloggs"
- EXTERNAL\_CONFIG\_FILE: Path to optional config file. Defaults to /gitconfig

### Examples

```
# A simple run to test the image:
docker run --rm bauk/git:2.24.0 --help
docker run --rm bauk/git:2.24.0 --version

# To start an interactive shell
docker run --rm -it bauk/git:2.24.0 sh
docker run --rm -it bauk/git:2.24.0 bash

# To run commands on a repo on your box:
docker run --rm --user $UID -v /path/to/host/repo:/git bauk/git:2.24.0 show
docker run --rm --user $UID -v /path/to/host/repo:/git bauk/git:2.24.0 log -n3

# To start an interactive session when you are currently inside the repo you want
docker run --rm -it --user $UID -v $PWD:/git bauk/git:2.24.0 bash

# To load in your own git config file
docker run --rm -it -v ~/.gitconfig:/gitconfig bauk/git:2.24.0 bash

# To load in an individual config item, e.g. user.name
docker run --rm -it -e "CFG_USER_NAME=Joe Bloggs" bauk/git:2.24.0 config --list

# Putting it all together and starting an interactive session
#  where you are currently in the repo and you get to keep all
#  your aliases.
docker run --rm -it --user $UID -v $PWD:/git -v ~/.gitconfig:/gitconfig bauk/git:2.24.0 bash
```

## Development/Builds

There is a tag for each corresponding docker build.
The script setupTags.sh will do a build and basic test and push up each version as a tag to be built by dockerhub.

The master branch is the base for all new tags.
To update tags, they need to be deleted and re-created from the new tip of master (for future master improvements).

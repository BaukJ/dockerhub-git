# bauk/dockerhub-git (bauk/git on Docker Hub)

## Intro

This repo is used for automated builds of bauk/git on dockerhub.

It is meant to be an easy way to trial or test with different versions of git, without having to install them manually.

## Tags

The following tags are available. Currently the default and only OS is centos.

|format|example|notes|
|------|-------|-----|
|{version}|2.24.0|The last CentOS build using that git version|
|{os}-{version}|centos-2.24.0|The last build of that OS and git version|
|{os}-{version}-{commit}|centos-2.24.0-712c3fe|The only tag that is sure to not get updated. The id of the master branch is used as a unique id|
|{os}|centos|The last build of the highest version number for that OS|
|latest|latest|The latest centos build of the highest version number|
|{type}|full|The latest build of that type. Default OS is assumed.|
|{type}-{version}|full-2.24.0|The build of that type with the specified git version installed. Default OS is assumed.|
|{os}-{type}|centos-full|The build of that OS and type with the specified git version installed.|
|{os}-{type}-{version}|full-2.24.0|The build of that type with the specified git version installed.|
|{os}-{type}-{version}-{commit}|full-2.24.0|The build of that type with the specified git version installed. Sure not to get updated as it has the id of the commit on the master branch as a unique identifier.|
|<b>INTERNAL|<b>TAGS|(Do not use as may change)|
|{os}-base|centos-base|Base image used by all images of that OS. To speed things up and make sharing easier|
|{os}-build-base|centos-build-base|Base image used by all build images of that OS. Based on top of the normal base but with tools to compile git, e.g. gcc|
|{os}-build-{version}|centos-build-2.24.0|Image with the compiled git code for that version. Used as a cache layer to stop the real builds needing to compile each time. This does however have that version of git installed as well as compiled. It just doesn't have all the entrypoint wrapping of the real image and is quite a bit larger|
|doce|docs|A centos-based image that just prints out this README. Used to keep the README in dockerhub up to date|

### Operating Systems / Bases (os)

|OS|Description|
|----|-----------|
|centos|The default OS and latest centos. Currently pointing to centos8.|
|centos8|Based on CentOS 8.|
|centos7|Obsolete. Based on CentOS 7 but no longer updated. Old versions will still exist.|

### Types

|Type|Description|
|----|-----------|
|-|Without a type, just a minimal image with git installed.|
|full|A fat image containing more tools like git-filter-repo, vim and git-lfs.|

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
docker run --rm bauk/git --help
docker run --rm bauk/git --version

# To start an interactive shell
docker run --rm -it bauk/git sh
docker run --rm -it bauk/git bash

# To run commands on a repo on your box:
docker run --rm --user $UID -v /path/to/host/repo:/git bauk/git show
docker run --rm --user $UID -v /path/to/host/repo:/git bauk/git log -n3

# To start an interactive session when you are currently inside the repo you want
docker run --rm -it --user $UID -v $PWD:/git bauk/git bash

# To load in your own git config file
docker run --rm -it -v ~/.gitconfig:/gitconfig bauk/git bash

# To load in an individual config item, e.g. user.name
docker run --rm -it -e "CFG_USER_NAME=Joe Bloggs" bauk/git config --list

# Putting it all together and starting an interactive session
#  where you are currently in the repo and you get to keep all
#  your aliases
docker run --rm -it --user $UID -v $PWD:/git -v ~/.gitconfig:/gitconfig bauk/git bash

# Same as above, but specifying the version of git (for checking different versions)
# If the version is not specified, it uses the latest version of git
docker run --rm -it --user $UID -v $PWD:/git -v ~/.gitconfig:/gitconfig bauk/git:1.8.2.3 bash
docker run --rm -it --user $UID -v $PWD:/git -v ~/.gitconfig:/gitconfig bauk/git:1.9.5 bash
docker run --rm -it --user $UID -v $PWD:/git -v ~/.gitconfig:/gitconfig bauk/git:2.12.5 bash
docker run --rm -it --user $UID -v $PWD:/git -v ~/.gitconfig:/gitconfig bauk/git:2.24.0 bash

# To remove all of a.zip from the history of your repo (for space or security reasons)
# Ensure you run this on a fresh clone, and you will have to re-write all of history to get it back
docker run --rm -it --user $UID -v $PWD:/git -v ~/.gitconfig:/gitconfig bauk/git:full filter-repo --path a.zip --invert-paths
```

### Custom git config

You can pass git config down to the image with environmental variables. e.g:

```
docker run --rm -it -e CFG_CORE_PAGER=less -e CFG_COLOR_UI=auto bauk/git config --list
```

## Development/Builds

There is a tag for each corresponding docker build.
The script setupTags.sh will do a build and basic test and push up each version as a tag to be built by dockerhub.

The master branch is the base for all new tags.
To update tags, they need to be deleted and re-created from the new tip of master (for future master improvements).

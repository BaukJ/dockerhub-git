# bauk/dockerhub-git (bauk/git on Docker Hub)

## Intro

This repo is used for automated builds of bauk/git on dockerhub.

It is meant to be an easy way to trial or test with different versions of git, without having to install them manually.

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
docker run --rm bauk/git:1.8.2.3 --help
docker run --rm bauk/git:1.8.2.3 --version

# To run commands on a repo on your box:
docker run --rm -v /path/to/host/repo:/git bauk/git:1.8.2.3 show
docker run --rm -v /path/to/host/repo:/git bauk/git:1.8.2.3 log -n3

# To start an interactive shell
docker run --rm -it bauk/git:1.8.2.3 sh
docker run --rm -it bauk/git:1.8.2.3 bash

# To load in your own git config file
docker run --rm -it -v /home/user/.gitconfig:/gitconfig bauk/git:1.8.2.3 bash

# To load in an individual config item, e.g. user.name
docker run --rm -it -e "CFG_USER_NAME=Joe Bloggs"
```

## Development/Builds

There is a tag for each corresponding docker build.
The script setupTags.sh will do a build and basic test and push up each version as a tag to be built by dockerhub.

The master branch is the base for all new tags.
To update tags, they need to be deleted and re-created from the new tip of master (for future master improvements).

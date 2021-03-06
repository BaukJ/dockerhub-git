#!/usr/bin/env perl
# BAUK_OPT:COMPLETION=1
use strict;
use warnings;
use BAUK::choices;
use BAUK::main;
use BAUK::files;
use BAUK::logg::buffer;
use BAUK::logg::commands;
use BAUK::errors;
use Cwd qw[abs_path];
use JSON;
# # # # # # #  CONFIG
my %commandOpts     = (
# --verbose and --help from BAUK::main->BaukGetOptions()
    'update|u'                  => "To update tags",
    'build|b'                   => "To build the image first to ensure it works",
    'group|g'                   => "Group mode, to push tags in groups for speed",
    'max|m=i'                   => "Max tags to update",
    'dir|d=s@'                  => "Dir to update",
    'sockets|s'                 => "To use ssh sockets to speed up pushes",
    'reverse|r'                 => "To reverse tag order and do newest first",
    'update-unbuilt|U'          => "To update any tags that have not been built",
    'minus-pending-from-max|M'  => "Minus any pending builds on dockerhub from the max. Requires a valid token.",
);
my $JSON = JSON->new()->pretty();
my $SCRIPT_DIR = abs_path(__FILE__ . "/..");
my $BASE_DIR   = abs_path("$SCRIPT_DIR/..");
chdir $BASE_DIR;
my $UPDATE_TAGS = 0;
my @CURRENT_BUILDS = ();
# # # # # # #  VARIABLES
my %opts = (
    sockets => sub {
        $ENV{GIT_SSH_COMMAND} = "ssh -oControlPath=$SCRIPT_DIR/.git.sock -oControlPersist=60s -oControlMaster=auto";
    },
    max => 30,
);
# # # # # # #  SUB DECLARATIONS
sub setup();
# # # # # # # # # # # # # # #  MAIN-START # # # # # # # # # # # # # #
setup();


prepareRepo();
logg(0, "Downloading versions...");
# TODO Do all curls in parallel as it saves time
my @dockerhub_tags = @{executeOrDie("curl --silent -f -lSL https://index.docker.io/v1/repositories/bauk/git/tags")->{log}};
my @git_versions = @{executeOrDie('curl -sS https://mirrors.edge.kernel.org/pub/software/scm/git/|sed -n "s#.*git-\([0-9\.]\+\).tar.gz.*#\1#p"|sort -V')->{log}};
@dockerhub_tags = map { $_->{name} } @{$JSON->decode(join('', @dockerhub_tags))};
logg(3, @dockerhub_tags);
logg(2, @git_versions);
my $latest_version = $git_versions[-1];
if(@ARGV){
    for my $v(@ARGV){
        unless(grep /^$v$/, @git_versions){
            loggDie("Version not found: $v");
        }
    }
    @git_versions = @ARGV;
}
if($opts{reverse}){
    @dockerhub_tags = reverse @dockerhub_tags;
    @git_versions   = reverse @git_versions;
}
logg(0, "Latest version: $latest_version. Total versions: ".($#git_versions+1));
updateLatest($latest_version);
updateDocs();
for my $dir(@{$opts{dir}}){
    $dir =~ s#/*$##;
    doDir({dir => $dir, versions => \@git_versions, max_updates => $opts{max}});
}
pushTags();


dieIfErrors();
logg(0, "SCRIPT FINISHED SUCCESFULLY");
# # # # # # # # # # # # # # #  MAIN-END # # # # # # # # # # # # # # #

# # # # # # #  SUBS
sub setup(){
    BaukGetOptions2(\%opts, \%commandOpts) or die "UNKNOWN OPTION PROVIDED";
    if($opts{"minus-pending-from-max"}){
        my %statuses = %{getDockerhubBuildStatuses()};
        my $pending = ($statuses{"In progress"} || 0) + ($statuses{"Pending"} || 0);
        $opts{max} -= $pending;
    }
    if($opts{max} > 0){
        logg(0, "MAX TAGS TO UPDATE: $opts{max}");
    }else{
        loggDie("MAX TAGS TO UPDATE IS 0. EXITING EARLY.");
    }
}
sub doVersion {
    my $in = shift;
    # loggBufferAppend("DOING VERSION");
    loggBufferSave();
    my $version = $in->{version} || die "TECHNICAL ERROR";
    my $dir = $in->{dir} || die "TECHNICAL ERROR";

    if(!$opts{build}){
        logg(0, "Not building as --build not specified. Assuming will work.");
        updateTag($in);
        return;
    }
    executeOrDie("sed -i 's/ARG VERSION=.*/ARG VERSION=$version/' $dir/Dockerfile-*");
    if($in->{last_working_minor} and $version =~ /^$in->{last_working_minor}/){
        logg(0, "Assuming it will work as minor worked: $in->{last_working_minor}");
    }elsif($in->{last_broken_minor} and $version =~ /^$in->{last_broken_minor}/){
        logg(0, "Assuming it will NOT work as minor did not: $in->{last_broken_minor}");
    }else{
        for my $dockerfile(glob "$dir/Dockerfile-*"){
            logg(0, "Doing version: $version ($dockerfile)");
            my %exec = execute("cd $dir && docker build . --file $dockerfile --tag git_tmp");
            if($exec{exit} != 0){
                logg(0, "Buid failed");
                $in->{last_broken_minor} = $version;
                $in->{last_broken_minor} =~ s/^([^0-9]*\.[^0-9]*).*/$1/;
                return;
            }
            my @log = @{executeOrDie("docker run --rm -it git_tmp --version")->{log}};
            unless(grep $version, @log){
                logg(0, "Buid corrupt somehow");
                $in->{last_broken_minor} = $version;
                $in->{last_broken_minor} =~ s/^([^0-9]*\.[^0-9]*).*/$1/;
                return 1;
            }
            logg(0, "Build success");
        }
        logg(0, "All builds successfull");
    }
    updateTag($in);
}
sub doDir {
    my $in = shift;
    my $dir = $in->{dir} || die "TECHNICAL ERROR";
    my @versions = @{$in->{versions} || die "TECHNICAL ERROR"};
    my $max_updates = $in->{max_updates} || die "TECHNICAL ERROR";
    # Ignore Dockerfiles-Builds as if the base build changes, we need it to build first before rebuilding the final image
    my $parent_commit = executeOrDie("git log -n1 --pretty=%h origin/master -- '$dir' ':!$dir/*test.yml' ':!$dir/hooks'")->{log}->[0];
    $in->{parent_commit} = $parent_commit;

    logg({fg=>"cyan"}, "DOING DIR: $dir");
    my $tag_prefix = $dir eq "app" ? "" : "$dir/";
    my @ALL_TAGS = @{executeOrDie("git tag")->{log}};
    my $count = 0;
    my $total = $#versions +1;
    for my $version(@versions){
        $count ++;
        my $version_tag = "${tag_prefix}${version}";
        my $docker_tag;
        loggBuffer(sprintf("%2s/%3s/%3s) %-10s:", $UPDATE_TAGS, $count, $total, $version));
        
        if($UPDATE_TAGS >= $max_updates){
            loggBuffer("Reached max tags to update ($max_updates)");
            loggBufferSave();
            return;
        }
        if($version =~ /^0/){
            loggBufferAppend("Skipping dev version");
            next;
        }
        if(grep /^$version_tag$/, @ALL_TAGS){
            logg(2, "Version exists: $version_tag");
            $in->{last_working_minor} = $version;
            $in->{last_working_minor} =~ s/^([^0-9]*\.[^0-9]*).*/$1/;
            my $tag_parent = executeOrDie("git show --pretty=%b -s $version_tag | sed -n 's/^PARENT: //p'")->{log}->[0];
            if($tag_parent eq $parent_commit){
                if($dir eq "app"){
                    $docker_tag = "centos-${version}-${parent_commit}";
                }elsif($dir eq "build"){
                    # Builds do not care about the parent commit, they are just compilation images
                    $docker_tag = "centos-$dir-${version}";
                }else{
                    $docker_tag = "centos-$dir-${version}-${parent_commit}";
                }
                if($opts{"update-unbuilt"}
                  && ! ((grep /^${docker_tag}$/, @dockerhub_tags)
                     || (grep /^centos-${version}$/, @CURRENT_BUILDS) # As builds in progress will not have the full docker tag with ID
                  )){
                    loggBufferAppend("RETAGGING TO REBUILD");
                    doVersion({%{$in}, version => $version});
                }elsif(grep /^${docker_tag}$/, @CURRENT_BUILDS){
                    loggBufferAppend("SKIPPING - up to date build in progress");
                    next;
                }else{
                    loggBufferAppend("SKIPPING - up to date");
                    next;
                }
            }elsif($opts{update}){
                loggBufferAppend("UPDATING due to new commits");
                logg(3, "$tag_parent..$parent_commit");
                doVersion({%{$in}, version => $version});
            }else{
                loggBufferAppend("SKIPPING - pass -u flag to update");
            }
        }else{
            logg(0, "New version: $version_tag");
            doVersion({%{$in}, version => $version});
        }
    }
    loggBufferEnd();
}
sub updateTag {
    my $in = shift;
    my $version = $in->{version};
    my $dir = $in->{dir};
    my $tag_prefix = $dir eq "app" ? "" : "$dir/";
    executeOrDie("git reset origin/master");
    executeOrDie("sed -i 's/ARG VERSION=.*/ARG VERSION=$version/' $dir/Dockerfile-*");
    executeOrDie("git add -- $dir/Dockerfile-*");
    executeOrDie("git commit --allow-empty -m 'AUTOMATIC COMMIT FOR $version' -m 'PARENT: $in->{parent_commit}'");
    executeOrDie("git tag -f ${tag_prefix}$version");
    pushTag("${tag_prefix}$version");
    $in->{last_working_minor} = $version;
    $in->{last_working_minor} =~ s/^([^0-9]*\.[^0-9]*).*/$1/;
}
sub pushTags {
    return unless $opts{group};
    if($UPDATE_TAGS){
        logg(0, "Updating tags");
        if(choiceYN("You have $UPDATE_TAGS tags to update. Update them [y/n]? :")){
            executeOrDie("git push --tags --force")
        }else{
            logg(0, "Reverting tags...");
            executeOrDie("git fetch --tags --force");
        }
    }
}
sub updateDocs {
    my $docs_commit = executeOrDie("git log -n1 --pretty=%H origin/master -- 'README*' 'DocsDockerfile'")->{log}->[0];
    my $last_docs_commit = executeOrDie("git rev-parse refs/tags/docs")->{log}->[0];
    if($docs_commit ne $last_docs_commit){
        logg(0, "Updating docs: $last_docs_commit -> $docs_commit");
        executeOrDie("git tag -f docs '$docs_commit'");
        pushTag("docs");
    }else{
        logg(0, "Docs up to date: $docs_commit");
    }
}
sub pushTag {
    my $tag = shift;
    $UPDATE_TAGS += 1;
    executeOrDie("git push -f origin $tag 2>&1") unless $opts{group};
}
sub prepareRepo {
    executeOrDie("git fetch --prune");
    executeOrDie("git fetch --prune --tags --force");
    executeOrDie("git checkout origin/master 2>&1");
}
sub updateLatest {
    my $latest_version = shift;
    my @log = @{executeOrDie("git tag --list latest -n1")->{log}};
    if(grep /VERSION: $latest_version$/, @log){
        logg(0, "Latest up to date: '$latest_version'");
    }else{
        logg(0, "Updating latest version to '$latest_version'");
        executeOrDie("git tag -f latest 4b825dc642cb6eb9a060e54bf8d69288fbee4904 -m 'VERSION: $latest_version'");
        executeOrDie("git push -f origin latest:refs/tags/latest");
    }
}
sub getDockerhubBuildStatuses {
    my $max_items = 50;
    my $token = getDockerhubToken();
    chomp $token;
    my %exec = loggExec({logg => "Fetching Dockerhub builds", command =>"curl -sS --compressed --fail"
        ." 'https://hub.docker.com/api/audit/v1/action/?include_related=true&limit=${max_items}&object=%2Fapi%2Frepo%2Fv1%2Frepository%2Fbauk%2Fgit%2F'"
        ." -H 'Accept: application/json'"
        ." -H 'Content-Type: application/json'"
        ." -H 'Cookie: token=$token'"});
    my @builds = @{$JSON->decode(join("", @{$exec{log}}))->{objects}};
    my %statuses = ();
    @CURRENT_BUILDS = ();
    for my $build(@builds){
        $statuses{$build->{state}}++;
        if($build->{state} eq "Pending" or $build->{state} eq "In Progress"){
            push @CURRENT_BUILDS, $build->{build_tag};
        }
    }
    logg(2, "Current builds:", @CURRENT_BUILDS);
    logg(0, "Last $max_items builds: ", $JSON->encode(\%statuses));
    return \%statuses;
}
sub getDockerhubToken {
    if(! -f "$SCRIPT_DIR/dockerhub_token"){
        unless(-f "$SCRIPT_DIR/dockerhub_username" && -f "$SCRIPT_DIR/dockerhub_password"){
            die "dockerhub_token not found, and neither was username and password!";
        }
        my $username = readFileToString("$SCRIPT_DIR/dockerhub_username");
        my $password = readFileToString("$SCRIPT_DIR/dockerhub_password");
        chomp $username;
        chomp $password;
        my $token = $JSON->decode(join("", @{executeOrDie("curl -sS -H 'Content-Type: application/json' -X POST -d '{\"username\":\"$username\",\"password\":\"$password\"}' 'https://hub.docker.com/v2/users/login/'")->{log}}))->{token};
        open my $fh, ">", "$SCRIPT_DIR/dockerhub_token" or die "$!";
        print $fh $token;
        close $fh;
        return $token;
    }
    return readFileToString("$SCRIPT_DIR/dockerhub_token");
}

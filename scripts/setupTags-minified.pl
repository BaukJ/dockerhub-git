#!/usr/bin/env perl
# BAUK_OPT:COMPLETION=1
use strict;
use warnings;
    ########## use BAUK::choices   - START #####
    BEGIN {
    package BAUK::choices;
    use strict;
    use warnings;
        ########## use BAUK::bauk      - START #####
        BEGIN {
        package BAUK::bauk;
        use strict;
        use warnings;
            ########## use BAUK::logg::simple - START #####
            BEGIN {
            package BAUK::logg::simple;
            use strict;
            use warnings;
            my $USE_BEFFER = 1; # If we end up using libraries in the future
            use Exporter qw(import);
            our @EXPORT = qw(logg setLoggLevel setLoggColour getLoggColour incrementLoggLevel setLoggFile loggTitle getLoggLevel loggAppend loggColour);# loggBuffer loggBufferAppend);
            my $VERBOSE = 0;
            my $COLOUR  = 1;
            my @opts = (
                {name => "verbose", key => "verbose|v+", desc => "Incremental argument for verbosity"},
            );
            my $LOGFILE = "";
            my %colours = (
                purple  => "\033[35m",
                green   => "\033[32m",
                default => "\033[39m",
            );
            my %foregrounds = (
                black           => "30",
                red             => "31",
                green           => "32",
                orange          => "33",
                blue            => "34",
                purple          => "35",
                cyan            => "36",
                light_grey      => "37",
                grey            => "1;30",
                light_red       => "1;31",
                light_green     => "1;32",
                yellow          => "1;33",
                light_blue      => "1;34",
                light_purple    => "1;35",
                light_cyan      => "1;36",
                white           => "1;37",
                default         => "39",
            );
            my %backgrounds = (
                black           => "40",
                red             => "41",
                green           => "42",
                orange          => "43",
                blue            => "44",
                purple          => "45",
                cyan            => "46",
                light           => "47",
                default         => "49",
            );
            my %specials = (
                underline       => 4,
                blink           => 5,
                inverse         => 7,
                default         => 55,
            );
            my %types   = (
                diff => sub {
                    my $format = shift;
                    my $line = shift;
                    if($line =~ /^>/){
                        $format->{colour} = "green";
                    }elsif($line =~ /^</){
                        $format->{colour} = "red";
                    }elsif($line =~ /^[0-9]/){
                        $format->{colour} = "cyan";
                    }elsif($line =~ /^-/){
                        $format->{colour} = "cyan";
                    }
                    BAUK::logg::simple::logg($format, $line);
                }
            );
            my @BUFFER       = ();  # Messages that are going to get overwritten (e.g. loading bars)
            my $SCREEN_WIDTH = 100; # Used to clean the buffer
            sub setupBaukLogging($$){
                my $commandOptsRef = shift;
                my $optsRef = shift;
                my $NEEDED = 1;
                for(keys %$commandOptsRef){
                    $NEEDED = 0 if(/verbose/);
                }
                if($NEEDED){
                    $$commandOptsRef{verbose} = "To increase the verbosity";
                    $$optsRef{verbose}  = sub {$VERBOSE++;};
                }
            }
            sub inputWasPassed {
                return 0 unless(defined $_[0]);
                my $i = $_[0];
                if(ref $i eq 'HASH'  or  $i =~ m/^[0-9><=+!]*$/){
                    return 1;
                }
                return 0;
            }
            sub _transferHashValue {
                my $in       = shift;
                my $toHash   = $in->{to}   || die "SCRIPT ERROR: Need to give to";
                my $fromHash = $in->{from} || die "SCRIPT ERROR: Need to give from";
                my $key      = $in->{key}  || die "SCRIPT ERROR: Need to give key";
                my @aliases  = @{$in->{aliases} || []};
                unshift @aliases, $key;
                for my $alias(@aliases){
                    if(defined $fromHash->{$alias}){
                        $toHash->{$key} = $fromHash->{$alias};
                        return 1;
                    }
                }
                $toHash->{$key} = $in->{default} if(defined $in->{default});
                return 0;
            }
            sub _transformInput {
                my $input = shift || {};
                my $hash = {};
                if(ref $input ne 'HASH'){
                    $input = {level => $input};
                }
                BAUK::logg::simple::_transferHashValue({from=>$input,to=>$hash,key=>"level"         ,aliases=>[qw[l]],  default=>0});
                BAUK::logg::simple::_transferHashValue({from=>$input,to=>$hash,key=>"foreground"    ,aliases=>[qw[colour fg]]});
                BAUK::logg::simple::_transferHashValue({from=>$input,to=>$hash,key=>"background"    ,aliases=>[qw[bg]]});
                BAUK::logg::simple::_transferHashValue({from=>$input,to=>$hash,key=>"special"       ,aliases=>[qw[s]]});
                BAUK::logg::simple::_transferHashValue({from=>$input,to=>$hash,key=>"dump"          ,aliases=>[qw[d]]});
                BAUK::logg::simple::_transferHashValue({from=>$input,to=>$hash,key=>"format"        ,aliases=>[qw[f]],  default=>1});
                BAUK::logg::simple::_transferHashValue({from=>$input,to=>$hash,key=>"type"          ,aliases=>[qw[t]]});
                BAUK::logg::simple::_transferHashValue({from=>$input,to=>$hash,key=>"returnMessage" ,aliases=>[qw[return]]});
                return $hash;
            }
            sub _containsKey {
                my $hash = shift;
                for my $key(@_){
                    return 1 if defined $hash->{$key};
                }
            }
            sub _clearLine {
                print "\r".(" "x$SCREEN_WIDTH)."\r";
            }
            sub _levelPrefix {
                my $level = shift;
                return ">"x$level if($level < 5);
                return (">"x(3-length($level))).$level.">>";
            }
            sub logg;
            sub logg {
                my ($LEVEL, $colour, $format, $input, $type, $dump);
                if(inputWasPassed @_){
                    $input = shift;
                }else{
                    $input = 0;
                }
                BAUK::logg::simple::logg(4, "No lines given to BAUK::logg::simple::logg (Input: $input)") unless @_;
                # Get Input
                my $opts = ();
                if(ref $input eq "HASH"){
                    $opts = BAUK::logg::simple::_transformInput($input);
                    $LEVEL  = $opts->{level};
                    $format = $opts->{format};
                    $dump   = $opts->{dump};
                    $type   = $opts->{type};
                    # Do we need to add 'colours'
                    if(BAUK::logg::simple::_containsKey($opts, qw[foreground background special])){
                        my @spec = ();
                        for(['foreground', \%foregrounds], ['background', \%backgrounds], ['special', \%specials]){
                            my ($name, $hash) = @{$_};
                            my $givens = $opts->{$name};
                            next unless $givens;
                            for my $given(split(" *, *", $givens)){
                                if($hash->{$given}){
                                    push @spec, $hash->{$given};
                                }else{
                                    warn "$name '$given' does not exist\nUse one of: ",join(", ", sort keys %{$hash}),"\n";
                                }
                            }
                        }
                        $colour = "\033[".join(";", @spec)."m" if @spec;
                    }
                }else{
                    $LEVEL = $input;
                    $colour = 0;
                    $format = 1;
                }
                # If type specified, special logging occurs
                if($type){
                    if(not $types{$type}){
                        warn "Type '$type' does not exist\nUse one of: ",join(", ", sort keys %types);
                    }else{
                        for(@_){
                            $types{$type}->({level=>$LEVEL}, $_);
                        }
                        return;
                    }
                }
                my $message = "";
                my $logFile;
                if($LOGFILE and BAUK::logg::simple::logIt({level=>$LEVEL,offset=>3})){
                    open $logFile, ">>", $LOGFILE or die "Could not open log file '$LOGFILE'";
                }
                if(BAUK::logg::simple::logIt({level=>$LEVEL})){
                    # Clear the buffer to log the current message, then add it back in.
                    if(@BUFFER){
                        BAUK::logg::simple::_clearLine();
                    }
                    # Create message
                    for(@_){
                        $message .= BAUK::logg::simple::_levelPrefix($LEVEL)  if($format);
                        $message .= $colour               if($COLOUR and $colour);
                        $message .= " "                   if($format);
                        if($dump){
                            $message .= BAUK::logg::simple::loggDump($_);
                        }else{
                            $message .= $_;
                        }
                        $message .= "\033[0m"     if($COLOUR and $colour);
                        $message .= "\n"          if($format);
                    }
                    # Write out message
                    print $message;
                    print $logFile $message if $logFile;
                    # Add the removed buffer back in if removed
                    if(@BUFFER){
                        print $BUFFER[0];
                    }
                }
                close $logFile if $logFile;
                return $message if $opts->{returnMessage};
                return BAUK::logg::simple::logIt({level=>$LEVEL});
            }
            sub loggColour {
                my $opts;
                if(inputWasPassed @_){
                    $opts = BAUK::logg::simple::_transformInput(shift);
                }else{
                    $opts = {};
                }
                for my $logg(@_){
                    for my $subLogg(split(/(<%[a-z]*%.*?%>)/, $logg)){
                        next unless $subLogg;
                        if($subLogg =~ s/<%([a-z]*)%(.*?)%>/$2/){
                            BAUK::logg::simple::logg({%{$opts}, f=>0, fg=>$1}, $subLogg);
                        }else{
                            BAUK::logg::simple::logg({%{$opts}, f=>0}, $subLogg);
                        }
                    }
                    BAUK::logg::simple::logg($opts, ""); # To add newlines if they were asked for
                }
            }
            sub loggAppend {
                if(@BUFFER){
                    BAUK::logg::simple::loggBufferAppend(@_);
                }else{
                    BAUK::logg::simple::logg(@_);
                }
            }
            sub _loggBuffer {
                my $in = shift;
                my %givenOpts = %{BAUK::logg::simple::_transformInput($in->{opts} || {})};
                my $line = defined($in->{logg}) ? $in->{logg} : '';
                my %opts = (
                    %givenOpts,
                    bufferUntil     => 1, # At this logg level, stop buffering # TODO: allow different levels passed
                    format          => 0, # Stop newlines getting appended
                    level           => 0, # TODO: Only allow buffers of level 0 at the moment
                    returnMessage   => 1, # To get the colourful message
                );
                if(defined $BUFFER[0] and not $in->{append}){
                    if(BAUK::logg::simple::logIt({level=>$opts{bufferUntil}})){
                        # If log level is high enough, we want to logg all and don't buffer
                        print "\n";
                    }else{
                        # else clean the line and print the new one over the top
                        BAUK::logg::simple::_clearLine();
                    }
                }
                my @oldBuffer = @BUFFER;
                @BUFFER = ();
                my $message = BAUK::logg::simple::logg(\%opts, $line);
                if($in->{append}){
                    @BUFFER = @oldBuffer;
                    $BUFFER[0] .= $message;
                }else{
                    @BUFFER = ($message);
                }
            }
            sub parseBufferInput {
                my $input = {};
                if($#_ == -1){
                    die "Need to provide at least one input to loggBuffer commands";
                }elsif($#_ == 0){
                    my $arg = shift;
                    if(ref $arg eq 'HASH'){
                        return $arg;
                    }else{
                        return {logg=>$arg};
                    }
                }elsif($#_ == 1){
                    my ($a1, $a2) = @_;
                    die "If passing two args to loggBuffer commands, first needs to be loggOpts, second needs to be loggMessage" if(ref $a1 ne 'HASH');
                    die "If passing two args to loggBuffer commands, first needs to be loggOpts, second needs to be loggMessage" if(ref $a2 ne '');
                    return {opts=>$a1,logg=>$a2};
                }else{
                    die "Cannot provide more than two arguments to loggBuffer commands";
                }
                return $input;
            }
            sub loggBufferAppend {
                my $in = BAUK::logg::simple::parseBufferInput(@_);
                $in->{append} ||= 1;
                BAUK::logg::simple::_loggBuffer($in);
            }
            sub loggBuffer {
                my $in = BAUK::logg::simple::parseBufferInput(@_);
                BAUK::logg::simple::_loggBuffer($in);
            }
            sub loggBufferInUse {
                return 1 if(@BUFFER);
                return 0;
            }
            sub loggBufferClear {
                if(@BUFFER){
                    BAUK::logg::simple::_clearLine();
                    @BUFFER = ();
                }else{
                    BAUK::logg::simple::logg(6, "WARNING: Tried clearing buffer, but nothing in buffer to clear");
                }
            }
            sub loggBufferSave {
                if(@BUFFER){
                    print "\n";
                    @BUFFER = ();
                }else{
                    BAUK::logg::simple::logg(6, "WARNING: Tried saving buffer, but nothing in buffer to save");
                }
            }
            sub loggBufferEnd {
                if(BAUK::logg::simple::logIt({level=>1})){
                    BAUK::logg::simple::loggBufferSave();
                }else{
                    BAUK::logg::simple::loggBufferClear();
                }
            }
            sub logIt {
                # Decide if to log
                my $in = shift;
                my $verbose = $in->{verbose};
                   $verbose = $VERBOSE unless(defined $verbose);
                my $level   = $in->{level};
                my $offset  = $in->{offset} || 0;
                $verbose += $offset;
                my $logIt = 0;
                if($level =~ /^[0-9]*$/ or $level =~ s/>=([0-9]*)$/$1/ or $level =~ s/=>([0-9]*)$/$1/){
                    $logIt = 1 if($verbose >= $level);
                }elsif($level =~ s/^<([0-9]*)$/$1/){
                    $logIt = 1 if($verbose < $level);
                }elsif($level =~ s/^=+([0-9]*)$/$1/){
                    $logIt = 1 if($verbose == $level);
                }elsif($level =~ s/^>([0-9]*)$/$1/){
                    $logIt = 1 if($verbose > $level);
                }elsif($level =~ s/^!=([0-9]*)$/$1/){
                    $logIt = 1 if($verbose != $level);
                }else{
                    die "Invalid logg level passed '$level'";
                }
                return $logIt;
            }
            sub loggDump($);
            sub loggDump($){
                my $p = shift;
                if(not defined $p){
                    return '<NULL>';
                }elsif(ref $p eq "HASH"){
                    return "{".join(",", map{"$_:".loggDump($p->{$_})} sort keys %{$p})."}";
                }elsif(ref $p eq "ARRAY"){
                    return "[".join(",", map{BAUK::logg::simple::loggDump($_)} @{$p})."]";
                }else{
                    return $p;
                }
            }
            sub loggTest(){
                print "\n\n\n\n\n\n\n\n\n\n";
                for(0..5){
                    $VERBOSE = $_;
                    print "LOG LEVEL SET TO $VERBOSE:\n";
                    BAUK::logg::simple::logg($_, "Logging with a level of $_/5") for(0..5);
                }
                print "---\n";
                for(sort keys %foregrounds){
                    BAUK::logg::simple::logg({fg => $_, l=>1}, "Logging in the colour $_");
                }
                print "---\n";
                for(sort keys %backgrounds){
                    BAUK::logg::simple::logg({bg => $_}, "Logging with a background colour $_");
                }
                print "---\n";
                for(sort keys %specials){
                    BAUK::logg::simple::logg({special => $_}, "Logging with special $_");
                }
                print "---\n";
                BAUK::logg::simple::logg({type=>"diff"}, "Testing the 'diff' type...", "- File x/y/z", "  lines...", "> Added this line", "< Removed this line", "  lines...");
                print "---\n";
                BAUK::logg::simple::loggBuffer("TESTING BUFFER");
                for(1..5){
                    select undef, undef, undef, 0.2;
                    BAUK::logg::simple::loggBufferAppend(".");
                }
                BAUK::logg::simple::loggBufferSave();
            }
            sub loggTitle($;$) { # BAUK::bauk::title(<title>,<underline>,<overhang>)
                my $loggRef = ($#_ > 0) ? shift : 0;
            	my $titleRef = shift;
                my %title = (title => "TITLE HERE", underline => "-", overhang => 1, space => 3, format => 1);
                if(ref $titleRef eq "HASH"){
                    $title{$_} = ${$titleRef}{$_} for(keys %{$titleRef});
                    $title{title}     = $title{t}       if(defined $title{t});
                    $title{underline} = $title{under}   if(defined $title{under});
                    $title{underline} = $title{u}       if(defined $title{u});
                    $title{overhang}  = $title{over}    if(defined $title{over});
                    $title{overhang}  = $title{o}       if(defined $title{o});
                    $title{space}     = $title{s}       if(defined $title{s});
                }else{
                    $title{title} = $titleRef;
                }
                my $space       = $title{space};
            	my $title       = " " x $space . $title{title};
                my $underline   = $title{underline};
                my $overhang    = $title{overhang};
                my $underlineOverhang = "$underline" x $overhang;
                my $length      = length $title{title};
                my $underTitle  = " " x ($space - $overhang) . "$underline" x ($length + (2 * $overhang));
                print "\n" if $title{format};
            	BAUK::logg::simple::logg($loggRef, $title);
                BAUK::logg::simple::logg($loggRef, $underTitle);
            }
            sub loggUsage(){
                die "TODO: not yet implemented";
            }
            sub setLoggFile($){
                $LOGFILE = shift;
            }
            sub setLoggColour($){
                $COLOUR = shift;
            }
            sub getLoggColour(){
                return $COLOUR;
            }
            sub getLoggLevel(){
                return $VERBOSE;
            }
            sub setLoggLevel($){
                $VERBOSE = shift;
            }
            sub incrementLoggLevel(){
                $VERBOSE++;
            }
            if(-t STDIN && (-t STDOUT || !(-f STDOUT || -c STDOUT))){ # If attached to a terminal (else this fails)
                eval "use Term::ReadKey;";
                if($@){ # If the module could not be loaded
                    warn "Could not load Term::ReadKey so termical outputs may not be great";
                }else{
                    my ($wchar, $hchar, $wpixels, $hpixels) = ();
                    # Occasionally get errors (e.g. when piping through to another app)
                    eval '($wchar, $hchar, $wpixels, $hpixels) = GetTerminalSize();';
                    $SCREEN_WIDTH = $wchar unless $@;
                }
            }else{
                BAUK::logg::simple::logg(6, "WARNING: Not attached to a terminal so not buffering");
            }
            1;
            }
            ########## use BAUK::logg::simple - END   #####
        use Carp;
        use Exporter qw(import);
        our @EXPORT = qw(title execute executeOrDie printme baukHelp echo vim perl makeDirs maxLength loadingLine touchFile unique);
        sub title { # title(<title>,<underline>,<overhang>)
        	my @titleData = @_;
        	my $title = $titleData[0];
        	my $underline = "-";
        	if(exists $titleData[1]) {$underline = $titleData[1];}
        	my $overhang = 1;
        	if(exists $titleData[2]) {$overhang  = $titleData[2];}
            my $underlineOverhang = "$underline" x $overhang;
        	print "\n$title\n";
        	$title =~ s/[^ ]/$underline/g;
            #$underline = "$underline" x $overhang ;
        	$title =~ s/ {$overhang}[^ ]/$underline$underlineOverhang$underlineOverhang/;
        	$title =~ s/[^ ] [^ ]/$underline$underline$underline/g;
        	#$title =~ s/$/={5}/;
        	#$title =~ s//$1$underline\{$overhang\}/;
        	print "$title\n";
        }
        sub unique(@){
            do { my %seen; grep { !$seen{$_}++ } @_ };
        }
        sub touchFile(@){
            for(@_){
                next if(-f $_);
                open my $fh, ">", $_;
                close $fh;
            }
            my $atime = my $mtime = time;
            utime $atime, $mtime, @_;
        }
        sub execute($){
            my $command = shift;
            BAUK::logg::simple::logg(6, "EXECUTING COMMAND: $command");
            my @log = `$command`;
            my $exit = $? >> 8;
            chomp for @log;
            BAUK::logg::simple::logg(7, "COMMAND RETURNED ($exit): ", @log);
            return (log => \@log, exit => $exit);
        }
        sub executeOrDie($){
            my $command = shift;
            my %ret = BAUK::bauk::execute($command);
            if($ret{exit}){
                croak "Command failed $ret{exit}: $command
                Log: ".join("\n", @{$ret{log}});
            }
            return \%ret;
        }
        sub maxLength(@){
            my $ret = 0;
            for(@_){
                next if(not defined $_);
                $ret = length($_) if(length($_) > $ret);
            }
            return $ret;
        }
        sub printme {
        	if ($#_ > 1 ) {
        	printf("\n     ~~~~~ %-$_[0]s ~~~~~\n", $_[1]);
        	}else{
        	print "\n     ~~~~~ @_ ~~~~~\n";
        	}
        }
        sub baukHelp($$){
            my %flags = %{$_[0]};
            my %args  = %{$_[1]};
            print "
            OPTIONS
          ===========\n";
            if(%flags){
                print "   flags\n  -------\n";
                for (keys %flags){
                    printf "   %-2s: %s\n", $_, $flags{$_};
                }
                print "\n";
            }
            if(%args){
                print "   arguments\n  -----------\n";
                for (keys %args){
                    printf "   %-2s: %s\n", $_, $args{$_};
                }
                print "\n";
            }
        }
        sub echo(@){
            print "$_\n" for (@_);
        }
        sub vim(@){
            my $exit = system(vim => @_);
            die "Vim failed with code: $exit" if($exit != 0);
        }
        sub perl($@){
            my $file = shift @_;
            my $return = system($^X, "$file", @_);
            BAUK::logg::simple::logg(1, "PERL RETURNED: $return");
            return $return;
        }
        sub makeDirs(@){
            for (@_){
                if(-d "$_"){
                    BAUK::logg::simple::logg(1, "~~~ Dir already exists '$_'");
                }else{
                    mkdir "$_";
                    BAUK::logg::simple::logg(1, "~~~ Created dir '$_'");
                }
            }
        }
        1;
        }
        ########## use BAUK::bauk      - END   #####
    use Term::ReadKey;
    use Carp;
    use Exporter 'import';
    our @EXPORT    = qw(choice choiceN choiceYN);
    our @EXPORT_OK = qw(readTerm);
    my $CHOICEYN_DEFAULT = "";
    my $CHOICEYN_AUTO    = 0;
    1;
    sub readTerm {
        my $opts = shift || {};
        croak "Need to provide HASH to readTerm!" unless ref($opts) eq "HASH";
        my $secret = delete($opts->{secret}) || 0;
        my $prompt = delete($opts->{prompt}) || 0;
        croak "Invalid options passed to BAUK::choices::readTerm(): ".join(", ", keys %{$opts}) if %{$opts};
        print "$prompt: "  if($prompt);
        ReadMode('noecho') if($secret);
        my $read = <STDIN>;
        chomp $read;
        if($secret){
            ReadMode('restore');
            print "\n"; # To add newline normally achieved through Enter Key
        }
        return $read;
    }
    sub choiceYN($){ # $question or %{question=>"Q : ", default=>"y/n", auto=>"0/1"}
        my $in = shift;
        my %in = (ref $in eq "HASH") ? %{$in} : (question => $in);
        $in{default}  = $in{default}  || $in{d} || $CHOICEYN_DEFAULT;
        $in{auto}     = $in{auto}     || $in{a} || $CHOICEYN_AUTO;
        $in{question} = $in{question} || $in{q} || "";
        if($in{default} =~ /^[yY]/){$in{default} = "y";}
        elsif($in{default} =~ /^[nN]/){$in{default} = "n";}
        elsif($in{default}){die "Default needs to be y(es) or n(o)";}
        if($in{auto} =~ /^[yY]/){$in{auto} = 1;}
        elsif($in{auto} =~ /^[nN]/){$in{auto} = 0;}
        elsif($in{auto} !~ /^[01]$/){die "Auto needs to be 0/1";}
        die "Cannot auto without default!" if($in{auto} and not $in{default});
        unless($in{question} =~ /:\s*$/){
            $in{question} .= " (y/n) ";
            $in{question} .= "[$in{default}] " if($in{default});
            $in{question} .= ": ";
        }
        print $in{question};
        my $ans = $in{default};
        if($in{auto}){
            print " *$in{default}*\n";
        }else{
            for(1..5){
                $ans = <STDIN>;
                chomp $ans;
                $ans = $in{default} if($ans =~ /^\s*$/);
                if($ans =~ /^[YyNn]/){
                    last;
                }elsif($_ == 5){
                    die "Wrong answer provided 5 times. Dying...";
                }
                print "Try again. Must be y(es) or n(o) : ";
            }
        }
        return 1 if($ans =~ /^y/i);
        return 0;
    }
    sub choice($@) { # $question   @choices / \%choices
        my $ans;
        my $question = shift @_;
    	my @choices = ();
        my %choices = ();
        my $default;
        my $custom  = 0;
        my $show    = 0;
        die "Need to specify options for choice!" unless @_;
        if (ref $_[0] eq 'HASH'){
            %choices = %{$_[0]};
            $default = delete $choices{default} if exists $choices{default};
            $custom  = delete $choices{"*"}     if exists $choices{"*"};
            $show    = delete $choices{show}    if(exists $choices{show} and $choices{show} eq "1");
        }else{
            @choices = @_;
            if ($choices[0] eq ""){ shift @choices; $default = shift @choices;}
        }
        my $printChoices = sub {
            my $mL = BAUK::bauk::maxLength(keys %choices, @choices);
            print "\nChoices ";
            print "(* = default [$default])" if(defined $default);
            print ": \n";
            if(defined $default){
                printf "  * $default \n" if (@choices);
                printf "  * %-${mL}s : %s\n", $default, $choices{$default} if(%choices);
            }
            print  "  - $_\n" for (@choices);
            for (keys %choices) {
                next if(defined($default) and $default eq $_);
                printf "  - %-${mL}s : %s\n", $_, $choices{$_};
            }
            printf  "  - %-${mL}s : $custom\n", "" if($custom);
        };
        $printChoices->() if($show);
        print "$question";
    	while (1){
    		my $choice = BAUK::choices::readTerm();
            $ans = $choice  if($custom);
            $ans = $default if (defined($default) and ("$choice" eq "" or uc($choice) eq uc($default)));
            # First check case sensitive choice
    		foreach my $i(@choices, keys %choices){
    			$ans = $i if ($choice eq $i);
    		}
            last if defined $ans;
            # Now check case insensitive choice
    		foreach my $i(@choices, keys %choices){
    			$ans = $i if (uc($choice) eq uc($i));
    		}
            last if defined $ans;
            $printChoices->();
    		print "Incorrect input '$choice'. Try again: ";
    	}
        return $ans;
    }
    sub choiceN(@) { # (max) || (min,max)
        my($min ,$max);
        if($#_ == 0){
            $max = shift;
        }elsif($#_ == 1){
            $min = shift;
            $max = shift;
        }elsif($#_ == -1){
        }else{
            die "You can only pass (), (max) or (min,max) to choiceN";
        }
    	while (1){
    		my $choice = BAUK::choices::readTerm();
    		if ($choice !~ m/^-?[0-9]+$/) {
    			print "Incorrect input. '$choice' is not numeric. ";
    		}elsif(defined $max and $choice > $max) {
                print "Input '$choice' is too high (max $max). ";
    		}elsif(defined $min and $choice < $min) {
    				print "Input '$choice' is too low (min $min). ";
    		}else {
    			return $choice;
    		}
    		print " Try again: "
    	}
    }
    }
    ########## use BAUK::choices   - END   #####
    ########## use BAUK::main      - START #####
    BEGIN {
    use strict;
    use warnings;
        ########## use BAUK::logg      - START #####
        BEGIN {
        package BAUK::logg;
        use strict;
        use warnings;
            ########## use BAUK::utils     - START #####
            BEGIN {
            package BAUK::utils;
            use strict;
            use warnings;
            use Exporter qw(import);
            our @EXPORT = qw(getLargest getLongest setHash);
            sub getLargest(@){
                my $largest = 0;
                for my $num(@_){
                    $largest = $num if($num > $largest);
                }
                return $largest;
            }
            sub getLongest(@){
                my $longest = 0;
                for my $item(@_){
                    my $itemLength = 0;
                    if(ref $item eq "ARRAY"){
                        $itemLength = scalar(@{$item});
                    }elsif(ref $item eq "HASH"){
                        $itemLength = scalar(%{$item});
                    }else{
                        $itemLength = length $item;
                    }
                    $longest = $itemLength if($itemLength > $longest);
                }
                return $longest;
            }
            sub setHash($@){
                my $hashRef = shift;
                OUTER:
                for(@_){
                    my @opts = split("\\|", $_);
                    my $main = $opts[0] || die "Need to provide at least one value";
                       $main =~ s/^{(.*)}$/$1/;
                    for my $opt(@opts){
                        if($opt =~ s/^{(.*)}$/$1/){
                            if(defined $hashRef->{$opt}){
                                $hashRef->{$main} = $hashRef->{$opt};
                                next OUTER;
                            }
                        }else{
                            $hashRef->{$main} = $opt;
                            next OUTER;
                        }
                    }
                }
            }
            1;
            }
            ########## use BAUK::utils     - END   #####
            ########## use BAUK::logg::extra - START #####
            BEGIN {
            package BAUK::logg::extra;
            use strict;
            use warnings;
            use Exporter qw(import);
            our @EXPORT = qw(loggDie loggWarn);
            sub loggDie($@){
                my ($hash, @logg) = BAUK::logg::extra::getHashAndLogg({fg=>"red"}, @_);
                BAUK::logg::simple::logg($hash, map {"ERROR: $_"} @logg);
                exit 1;
            }
            sub loggWarn($@){
                my ($hash, @logg) = BAUK::logg::extra::getHashAndLogg({fg=>"orange"}, @_);
                BAUK::logg::simple::logg($hash, map {"WARN : $_"} @logg);
            }
            sub getHashAndLogg($@){
                my $defaultHash = shift;
                my %hash = %{$defaultHash};
                if (ref $_[0] eq "HASH"){
                    my $providedHash = shift;
                    %hash = (%{$providedHash}, %{$defaultHash});
                }
                return \%hash, @_;
            }
            1;
            }
            ########## use BAUK::logg::extra - END   #####
            ########## use BAUK::logg::loggTable - START #####
            BEGIN {
            package BAUK::logg::loggTable;
            use strict;
            use warnings;
            use Exporter qw(import);
            our @EXPORT = qw(loggTable);
            sub loggRow($);
            sub loggTable($){ # %{ (rows=>\@%rows || rows=>\@@rows,headers=>\@headers), title=>$title}
                my %in = %{$_[0]};
                my %opts = %{$in{opts} || {}};
                # Set default options
                $opts{null} = 'null' unless(defined $opts{null});
                $opts{align} ||= 'left';
                my $excel = $opts{excel} || 0; # Whether to do comma delimited fields (importable into excel)
                $opts{seperator}  ||= $excel ? ',' : '|';
                my $S = $opts{seperator};
                my @h = ($in{headers}) ? @{$in{headers}} : (); # sorted headers
                my %h = ();                    # headers
                my @rows = ();
                my $HASH = 0;
                # TODO: empty table, no rows
                if(ref $in{rows}[0] eq "HASH"){
                    $HASH = 1;
                    # Populate header list
                    unless(@h){
                        for (@{$in{rows}}){
                            my %row = %{$_};
                            $h{$_} = 0 for(keys %row);
                        }
                        @h = sort keys %h;
                    }
                    # Convert hash array into array array of only wanted values.
                    my @hashData = @{$in{rows}};
                    for my $hashRow(@hashData){
                        my @row = ();
                        push @row, ($hashRow->{$_}) for @h;
                        #push @row, ($hashRow->{$_} || "") for @h;
                        push @rows, \@row;
                    }
                }elsif(ref $in{rows}[0] eq "ARRAY" and ref $in{headers} eq "ARRAY"){
                    @rows = @{$in{rows}};
                }else{
                    die 'Need to provide either: {rows=>arrayOfHash} or {rows=>arrayOfarrays,headers=>array}';
                }
                # Set max Lengths for columns
                $h{$_} = length($_) for @h;
                for (@rows){
                    my @row = @{$_};
                    for my $n(0..$#h){
                        my $header = $h[$n];
                        my $dataLength = 0;
                        if(ref $row[$n] eq "ARRAY"){
                            for(@{$row[$n]}){
                                $dataLength = length($_) if(length($_) > $dataLength);
                            }
                        }else{
                            # Get the longest line in the row (lines are now split)
                            for(split("\n", $row[$n] || "")){
                                $dataLength = length($_) if(length($_) > $dataLength);
                            }
                        }
                        $h{$header} = $dataLength if($dataLength > $h{$header});
                    }
                }
                $h{$_}++ for(keys %h);
                my $header = $excel ? '' : $S;
                for my $h(@h){
                    if($excel){
                        $header .= "$h$S";
                    }else{
                        $header .= sprintf("%-$h{$h}s|", $h);
                    }
                }
                $header =~ s/$S$// if($excel);
                my $headerU = $header;
                $headerU =~ s/./-/g;
                BAUK::logg::simple::logg($headerU) unless($excel);
                if($in{title}){
                    use integer;
                    my $width = length($headerU) - 2;
                    my $pad = ($width - length($in{title})) / 2;
                    my $rest = $width - $pad;
                    BAUK::logg::simple::logg(sprintf("|%${pad}s%-${rest}s|", "", $in{title}));
                }
                BAUK::logg::simple::logg($header);
                BAUK::logg::simple::logg($headerU) unless $excel;
                if(defined $opts{sort}){
                    my $sortColumn = 0;
                    if($opts{sort} =~ /^[0-9]+$/){
                        $sortColumn = $opts{sort};
                    }else{
                        for(0..$#h){
                            if($h[$_] =~ /^$opts{sort}$/){
                                $sortColumn = $_;
                            }
                        }
                    }
                    BAUK::logg::simple::logg(5, "Sorting rows by $sortColumn ($opts{sort})");
                    @rows = sort {
                        my $numRegex = '[0-9]+(\.[0-9]*)*';
                        my $ac = $a->[$sortColumn];
                        my $bc = $b->[$sortColumn];
                        if(defined $ac and defined $bc){
                            if($ac =~ /^$numRegex$/ and $bc =~ /^$numRegex$/){
                                return $ac <=> $bc;
                            }
                            $ac cmp $bc;
                        }elsif(defined $ac){
                            return 1;
                        }elsif(defined $bc){
                            return -1;
                        }else{
                            return 0;
                        }
                    } @rows;
                }
                if($opts{reverse}){
                    BAUK::logg::simple::logg(5, "Reversing row order");
                    @rows = reverse(@rows);
                }
                for (@rows){
                    #loggRow(\%h, \@h, $_);
                    BAUK::logg::loggTable::loggRow({
                        hHash  => \%h,
                        hArray => \@h,
                        row    => $_,
                        opts   => \%opts,
                    });
                    #my @row = @{$_};
                    #my $row = "|";
                    #for(0..$#h){
                    #    $row[$_] = 'null' unless defined $row[$_];
                    #    chomp $row[$_];
                    #    $row .= sprintf("%-$h{$h[$_]}s|", ($row[$_] || ""));
                    #}
                    #logg($row);
                }
                BAUK::logg::simple::logg($headerU) unless $excel;
            }
            sub loggRow($){
                my $in = shift;
                my %h = %{$in->{hHash}};
                my @h = @{$in->{hArray}};
                my @row = @{$in->{row}};
                $in->{line} ||= 0;
                my $lines = 0;
                for(@row){
                    next if not defined $_;
                    my $rowLines;
                    if(ref $_ eq "ARRAY") {
                        $rowLines = scalar(@{$_}) - 1;
                    }else{
                        $rowLines = () = $_ =~ /\n/g;
                    }
                    $lines = $rowLines if($rowLines > $lines);
                }
                BAUK::logg::simple::logg(6, "LINES: $lines");
                my @rows = map {
                    my @a = (ref $_ eq "ARRAY") ? @{$_} : split("\n", $_ || "");
                    \@a;
                } @row;
                for my $l(0..$lines){
                    my @row = ();
                    for(@rows){
                        push @row, $_->[$l]
                    }
                    BAUK::logg::loggTable::loggR({%{$in}, row=>\@row, line=>$l});
                }
            }
            sub loggR($){
                my $in = shift;
                my %h = %{$in->{hHash}};
                my %o = %{$in->{opts}};
                my $S = $o{seperator};
                my @h = @{$in->{hArray}};
                my @row = @{$in->{row}};
                my $row = ($in->{line}) ? " " : ($o{excel} ? '' : $S); # TODO: Would this work with Excel
                for(0..$#h){
                    unless(defined $row[$_]){
                        $row[$_] = ($in->{line}) ? '' : $o{null};
                    }
                    chomp $row[$_];
                    if($o{excel}){
                        $row .= ($row[$_] || "").$S;
                    }elsif($o{align} =~ /^right$/i){
                        $row .= sprintf("%$h{$h[$_]}s|", ($row[$_] || ""));
                    }else{
                        $row .= sprintf("%-$h{$h[$_]}s|", ($row[$_] || ""));
                    }
                }
                $row =~ s/$S$// if($o{excel});
                BAUK::logg::simple::logg($row);
            }
            1;
            }
            ########## use BAUK::logg::loggTable - END   #####
            ########## use BAUK::logg::loggLoader - START #####
            BEGIN {
            package BAUK::logg::loggLoader;
            use strict;
            use warnings;
            use Term::ReadKey;
            use Exporter qw(import);
            our @EXPORT = qw(loggLoader);
            my %loadingUntils = (
                '0'     => sub {1;},
            );
            my %spinners = (
                spin    => {
                    counter => "-",
                    spinner => [qw(\ | / -)]
                },
                snail   => {
                    counter => ".",
                    spinner => [
                        ' /\\   ',
                        ' ___  ',
                    ],
                },
                ball    => {
                    counter => "|",
                    spinner => [
                        "#   ",
                        " #  ",
                        "  # ",
                        "   #",
                        "  # ",
                        " #  ",
                        "#   ",
                    ],
                },
                cradle  => {
                    counter => "",
                    spinner => [
                        "   ....   ",
                        "   ... .  ",
                        "   ...  . ",
                        "   ...   .",
                        "   ...  . ",
                        "   ... .  ",
                        "   ....   ",
                        "  . ...   ",
                        " .  ...   ",
                        ".   ...   ",
                        " .  ...   ",
                        "  . ...   ",
                    ],
                },
                logs    => {
                    counter => "|",
                    spinner => [
                        "|      ",
                        "||     ",
                        "|||    ",
                        "||||   ",
                        "|||||  ",
                        "||||   ",
                        "|||    ",
                        "||     ",
                        "|      ",
                    ],
                },
                text    => {
                    time    => 0.15,
                    spinner => sub {
                        my ($count, $data) = @_;
                        my $text = $data->{text} || "YOUR TEXT HERE";
                        my $size = $data->{size} || 20;
                        $text = " "x$size . $text . " "x$size;
                        my $length = length($text) - $size;
                        $count %= $length;
                        $text = substr $text, $count, $size;
                        return "[$text]";
                    },
                },
            );
            sub loggLoader($){
                my $in = shift;
                $in = {until=>$in} unless(ref $in eq "HASH");
                my $pad = (defined $in->{pad}) ? delete($in->{pad}) : 0;
                my $until       = $in->{until} || $in->{u} || 0;
                my $spinner     = $in->{spinner} || $in->{spin} || "spin";
                my %spinner;
                if(ref $spinner eq "HASH"){
                    %spinner = %{$spinner};
                }elsif(ref $spinner eq "ARRAY"){
                    %spinner = (%{$spinners{spin}}, spinner => $spinner);
                }else{
                    %spinner = %{$spinners{$spinner}};
                }
                %spinner = (%{$spinners{$spinner{name} || "spin"} || die "Invalid spinner name: $spinner{name}"}, %spinner);
                if(ref $spinner{spinner} eq "ARRAY"){
                    my $cycleTime   = 1;
                    my $spinnerTime = $cycleTime / (scalar @{$spinner{spinner}});
                    $spinner{time} ||= $spinnerTime;
                }
                $spinner{time} ||= 1;
                my $logg        = $in->{logg} || 0;
                my $newline     = (defined $in->{newline}) ? $in->{newline} : 1;
                my $time        = (defined $in->{time})    ? $in->{time}    : 1;
                BAUK::logg::simple::logg({l=>4,dump=>1}, "Starting loadingLine", "- time", $time, "- spinner", \%spinner);
                if($logg){
                    BAUK::logg::simple::logg({level=>0,format=>0}, sprintf("%-${pad}s", $logg));
                }
                my $count = -1;
                my $whileSub = sub {$_[0] < $until};
                local $SIG{INT} = sub {$whileSub = sub{return 0;}};
                if($until !~ /^[0-9]*$/ or $until eq "0"){
                    if(ref $until eq "CODE"){
                        $whileSub = $until;
                    }else{
                        $whileSub = $loadingUntils{$until} || die "No function to load until '$until'";
                    }
                }
                local $| = 1;
                ReadMode 2;
                my $startTime = time;
                while($whileSub->(++$count)){
                    if(ref $spinner{spinner} eq "ARRAY"){
                        for (@{$spinner{spinner}}){
                            print "$_";
                            select undef, undef, undef, $spinner{time};
                            my $length = length $_;
                            print "\b"x $length;
                            print " "x $length;
                            print "\b"x $length;
                            last unless($whileSub->($count));
                        }
                        print $spinner{counter};
                    }else{
                        my $s = $spinner{spinner}->($count, \%spinner);
                        print $s;
                        select undef, undef, undef, $spinner{time};
                        my $length = length $s;
                        print "\b"x $length;
                        print " "x $length;
                        print "\b"x $length;
                    }
                }
                my $endTime = time;
                if($time){
                    BAUK::logg::simple::loggAppend({level=>0,format=>0,colour=>"yellow"}, sprintf(" (%3ss)", $endTime - $startTime));
                }
                print "\n" if $newline;
                while(ReadKey(-1)){};
                ReadMode 0;
            }
            1;
            }
            ########## use BAUK::logg::loggLoader - END   #####
            ########## use BAUK::logg::loggBarGraph - START #####
            BEGIN {
            package BAUK::logg::loggBarGraph;
            use strict;
            use warnings;
            use Exporter qw(import);
            our @EXPORT = qw(loggBarGraph);
            sub loggBarGraph($){
                BAUK::logg::simple::logg(4, "loggBarGraph()");
                my $screenWidth = `tput cols`;
                chomp $screenWidth;
                my $tableColour = "blue";
                my $naColour    = "cyan";
                my $columns     = $screenWidth;
                my @data;
                my %opts;
                my $inRef = shift;
                if(ref $inRef eq "ARRAY"){
                    %opts = ();
                    @data = @{$inRef};
                }elsif(ref $inRef eq "HASH"){
                    if($inRef->{data}){
                        %opts = %{$inRef};
                        @data = @{$opts{data}};
                        BAUK::utils::setHash(\%opts, "{maxValue}|{max}", "{longestName}|{longest}");
                    }else{
                        my %data = %{$inRef};
                        for(keys %data){
                            push @data, {name => $_, value => $data{$_}};
                        }
                    }
                }
                BAUK::utils::setHash(\%opts, "{highColour}|{hColour}|{hC}|green",
                    "{medColour}|{mColour}|{mC}|orange",
                    "{lowColour}|{lColour}|{lC}|red",
                    "{lowerQuartile}|{lQuartile}|{lQ}|0.33",
                    "{upperQuartile}|{uQuartile}|{uQ}|0.66",
                    );
                for(@data){
                    BAUK::utils::setHash($_, "{name}|{n}|UNDEF", "{value}|{v}");
                }
                my $maxValue    = $opts{maxValue} || BAUK::utils::getLargest(map {$_->{value} || 0} @data);
                my $lowMax      = $maxValue * 0.33;
                my $medMax      = $maxValue * 0.66;
                my $longestName = $opts{longestName} || BAUK::utils::getLongest(map {$_->{name} || 0} @data);
                BAUK::logg::simple::logg(4, "loggBarGraph(): max = $maxValue, longest = $longestName");
                $columns -= ($longestName + 1); # For names and pipe at start
                $columns -= 2;                  # Pipes at ends
                BAUK::logg::simple::logg({l=>0,f=>0,fg=>$tableColour}, "_"x$screenWidth);
                if($opts{title}){
                    use integer;
                    my $width = $columns;
                    my $pad = ($width - length($opts{title})) / 2;
                    my $rest = $width - $pad;
                    BAUK::logg::simple::logg({l=>0,f=>0,fg=>$tableColour}, sprintf(" %${longestName}s %${pad}s%-${rest}s|\n", "", "", $opts{title}));
                }
                for(@data){
                    my %row = %{$_};
                    my $rowName = substr($row{name}, 0, $longestName);
                    BAUK::logg::simple::logg({l=>0,f=>0,fg=>$tableColour}, sprintf("|%-${longestName}s|", $rowName));
                    if(defined $row{value}){
                        my $rowColour = $opts{lowColour};
                        $rowColour = $opts{medColour} if($row{value} > $lowMax);
                        $rowColour = $opts{highColour} if($row{value} > $medMax);
                        my $size = ($row{value} / $maxValue) * $columns;
                        if($size > $columns){
                            BAUK::logg::simple::logg({l=>0,f=>0,fg=>$rowColour}, sprintf("%-".(${columns}-3)."s...", "#"x(${columns}-3)));
                        }else{
                            BAUK::logg::simple::logg({l=>0,f=>0,fg=>$rowColour}, sprintf("%-${columns}s", "#"x$size));
                        }
                    }else{
                        BAUK::logg::simple::logg({l=>0,f=>0,fg=>$naColour}, sprintf("%-${columns}s", "N/A"));
                    }
                    BAUK::logg::simple::logg({l=>0,f=>0,fg=>$tableColour}, "|\n");
                }
                BAUK::logg::simple::logg({l=>0,f=>0,fg=>$tableColour}, "_"x$screenWidth);
            }
            1;
            }
            ########## use BAUK::logg::loggBarGraph - END   #####
        use Exporter qw(import);
        our @EXPORT = qw(logg setLoggLevel setLoggColour getLoggColour incrementLoggLevel setLoggFile loggTitle getLoggLevel loggColour
            loggTable
            loggBarGraph
            loggLoader
            loggDie loggWarn
        );
        1;
        }
        ########## use BAUK::logg      - END   #####
        ########## use BAUK::config    - START #####
        BEGIN {
        package BAUK::config;
        use strict;
        use warnings;
        use Exporter qw(import);
        our @EXPORT = qw(getBaukConfig getBaukConfigValue setBaukConfigValue getBaukConfigFile setBaukConfigFile);
        my $DELIM       = "=";
        my $HASH_DELIM  = ":";
        my $CONFIG_FILE = ($ENV{BAUK_REPO}) ? "$ENV{BAUK_REPO}/bauk.config" : (($ENV{HOME}) ? "$ENV{HOME}/bauk.config" : "bauk.config");
        my %config = (
            #'MAIN.CLEANTEMP.ASK'        => "yes",
            #'MAIN.CLEANTEMP.DEFAULT'    => "yes",
            #'MAIN.CLEANTEMP.MIN_AGE'    => 0,
        );
        sub getAllBaukConfig();
        1;
        sub getBaukConfigFile(){
            return $CONFIG_FILE;
        }
        sub setBaukConfigFile($){
            $CONFIG_FILE = shift;
        }
        sub getBaukConfig($$){ # $uniqueConfigArea (dot delimited)   %hash_of_keys_and_default_values
            my ($area, $hashRef) = @_;
            my %specificConfigRaw = %{$hashRef};
            BAUK::logg::simple::logg(3,
                "Getting Config with BASE         : ".$area,
                "Getting Config with specific keys: ".join(" ", keys %specificConfigRaw));
            my %specificConfig = ();
            $specificConfig{"$area.$_"} = $specificConfigRaw{$_} for(keys %specificConfigRaw); # Prepend the area to the config
            BAUK::config::getAllBaukConfig();
            %specificConfigRaw = ();
            for my $key (keys %specificConfig){
                my $keyEnd = $key;
                   $keyEnd =~ s/^$area\.*//;
                if(not exists $config{$key}){
                    $config{$key} = BAUK::config::getBaukConfigValue($key, $specificConfig{$key}, 1);
                }
                $specificConfig{$key}       = $config{$key};
                $specificConfigRaw{$keyEnd} = $config{$key};
            }
            $hashRef->{$_} = $specificConfigRaw{$_} for(keys %specificConfigRaw); # Update the hashRef passed
            BAUK::config::saveBaukConfig();
            return %specificConfigRaw;
        }
        sub getBaukConfigValue($@){
            my $key          = shift;
            my $defaultValue = shift;
            my $putValue     = shift ;#|| 0;
            BAUK::config::getAllBaukConfig();
            if((not(defined $config{$key}) and defined $defaultValue) or $putValue){
                if(ref $defaultValue eq "HASH" and $key !~ m/\%$/){
                    $config{$key} = BAUK::config::askForConfigValue($key, $defaultValue);
                }else{
                    $config{$key} = $defaultValue;
                }
                BAUK::config::saveBaukConfig();
            }
            return @{$config{$key}} if(ref $config{$key} eq "ARRAY");
            return %{$config{$key}} if(ref $config{$key} eq "HASH");
            return $config{$key};
        }
        sub setBaukConfigValue($$){ # $item, $value
            return BAUK::config::getBaukConfigValue($_[0], $_[1], 1);
        }
        sub askForConfigValue($$){
            my $key     = shift;
            my %options = %{$_[0]};
               $options{show} = 1;
            return BAUK::choices::choice("Choose config value for '$key' : ", \%options);
        }
        sub getAllBaukConfig(){
            BAUK::logg::simple::logg(3, "GETTING BAUK CONFIG");
            my $fh;
            if(open($fh, "<$CONFIG_FILE")){
                while(<$fh>){
                    s/\s*$//; # Remove trailing spaces and new-line
                    if(/^#/){
                        # Comment line; do nothing
                    }else{
                        my @row = split " *$DELIM *", $_;
                        my $key = uc $row[0];
                        my $value;
                        if(defined $row[1]){$value = $row[1] ;}
                        else{ $value = $config{$key} || 0;}
                        BAUK::logg::simple::logg(6, sprintf("Obtaining Config %-35s with value: %s",$key, $value));
                        if($key =~ /\@$/){
                            BAUK::logg::simple::logg(7, sprintf("Obtaining Config %-35s with value: %s (%s)",$key, $value, ref $value));
                            # TODO: Fix array items
                            # TODO # if(ref $value eq "ARRAY"){
                            # TODO #     BAUK::logg::simple::logg(7, @{$value});
                            # TODO # }else{
                            # TODO #     warn "Config for key '$key' is invalid (not an array)"
                            # TODO # }
                            my @valueArray = split(", *", $value);
                            $config{$key} = \@valueArray;
                        }elsif($key =~ /\%$/){
                            my @valueArray = split(", *", $value);
                            my %hash = ();
                            for (@valueArray){
                                my @keyValue = split($HASH_DELIM, $_);
                                $hash{$keyValue[0]} = $keyValue[1];
                                $config{$key} = \%hash;
                            }
                        }else{
                            $config{$key} = $value;
                        }
                    }
                }
            }
            close $fh;
            return %config;
        }
        sub saveBaukConfig(){
            my $fh;
            open($fh, ">$CONFIG_FILE") or warn "Could not open config file '$CONFIG_FILE'";
            if($fh){
                print $fh "# Config for Bauk scripts/repo:\n";
                print $fh "# (To reset config, delete this file and it will re-generate)\n";
                for(sort keys %config){
                    if(/\@$/){
                        my @arrayValue = (ref $config{$_} eq "ARRAY") ? @{$config{$_}} : ($config{$_});
                        print $fh $_.$DELIM.join(",", @arrayValue)."\n";
                    }elsif(/\%$/){
                        my %hash = %{$config{$_}};
                        my @hashList = ();
                        push @hashList, "$_:$hash{$_}" for(keys %hash);
                        print $fh $_.$DELIM.join(",", @hashList)."\n";;
                    }else{
                        print $fh $_.$DELIM.$config{$_}."\n";
                    }
                }
            }
            close $fh;
        }
        }
        ########## use BAUK::config    - END   #####
        ########## use BAUK::Getopt    - START #####
        BEGIN {
        package BAUK::Getopt;
        use strict;
        use warnings;
        use Getopt::Long;
            ########## use BAUK::definitions - START #####
            BEGIN {
            package BAUK::definitions;
            use strict;
            use warnings;
            use Exporter qw(import);
            our @EXPORT = qw(error);
            my %errors = (
                SUCCESS             => 0 ,
                FAILURE             => 1 ,
                USER_EXIT           => 2 ,
                INVALID_ARGUMENTS   => 3 ,
            );
            sub error($);
            sub error($){
                $errors{$_[0]}
                    or die "Invalid error code name: '$_[0]'. Valid errors are:\n - ",join("\n - ", sort keys %errors),"\n\n";
                return $errors{$_[0]} ;
            }
            1;
            }
            ########## use BAUK::definitions - END   #####
            ########## use BAUK::Getopt::v2 - START #####
            BEGIN {
            package BAUK::Getopt::v2;
            use strict;
            use warnings;
            use Getopt::Long;
                ########## use BAUK::unc::utils - START #####
                BEGIN {
                package BAUK::unc::utils;
                use strict;
                use warnings;
                use Exporter 'import';
                our @EXPORT = qw();
                our @EXPORT_OK = qw(getScriptData);
                sub getCommentsFromFile {
                    my @comments = ();
                    my $file = shift;
                    open my $FH, "<", $file or die "Cannot read script '$file'";
                    while(my $line = <$FH>){chomp $line;
                        next if($line =~ /^#!/);
                        last if(not($line =~ s/^# ?//));
                        push @comments, $line;
                    }
                    return @comments;
                }
                sub getScriptData {
                    my $file = shift or die "TECHNICAL ERROR: BAUK::unc::utils::getScriptData() needs to provide a filename";
                    my %map = (
                        %{+shift || {}}
                    );
                    $map{commentsScraper} ||= \&getCommentsFromFile;
                    my @comments = $map{commentsScraper}->($file);
                    my %data = (comments => []);
                    for my $comment(@comments){
                        if($comment =~ s/^BAUK_OPT://){
                            if($comment =~ /=/){
                                my @args = split('=', $comment);
                                my $key = shift @args;
                                $data{$key} = join('=', @args);
                            }
                        }else{
                            push @{$data{comments}}, $comment;
                        }
                    }
                    return \%data;
                }
                1;
                }
                ########## use BAUK::unc::utils - END   #####
            use Exporter qw(import);
            our @EXPORT = qw(BaukGetOptions2);
            my @COMMON_OPTS = qw[--help --verbose --colour --nocolour];
            sub parse($$$;$);
            sub sortOptions($);
            sub BaukGetOptions2($$;$){
                my $optsRef = shift;        # Ref that will get the chosen options given to it
                my $commandOptsRef = shift; # Hash of the available options and sub-options (with descriptions in values)
                my %map = %{shift || {}};   # Extra options
                my $chosenCommands = [];    # Array that will contain all the sub-options the user has chosen
                my $dashesPassed = 0;
                # Default map
                %map = (
                    strict              => 1,
                    force_sub_commands  => 1,   # To force the use of sub-commands if they exist
                    force_all_args      => 1,   # To force all arguments to be read, if any are left, the script errors
                    %map
                );
                BAUK::Getopt::v2::addDefaultOptions($optsRef, $commandOptsRef, $chosenCommands);
                Getopt::Long::Configure ("bundling_override");
                Getopt::Long::Configure ("require_order");
                Getopt::Long::Configure("pass_through");
                # Don't parse anyting after --
                my @args = @ARGV;
                {
                    @ARGV = ();
                    while(@args){
                        my $arg = shift @args;
                        if($arg eq "--"){
                            $dashesPassed = 1;
                            last;
                        }
                        push @ARGV, $arg;
                    }
                }
                if($ARGV[0] and $ARGV[0] eq "_bauk_completion_options"){
                    shift @ARGV;
                    $map{generate_completion} = 1;
                    # Remove optsRef so that arguments don't spontaneously happen
                    $optsRef = {};
                }
                BAUK::Getopt::v2::parse($optsRef, $commandOptsRef, $chosenCommands, \%map);
                push @ARGV, '--' if(@ARGV and $dashesPassed); # If not all options parsed, add back in -- (Will only occur if strict turned off)
                                                              # Ths is needed for things like punc (where punc <command> -cf -- --extra_flag), you need the -- to persist into the command
                push @ARGV, @args;
                BAUK::logg::simple::logg(4, "Leftover args: @ARGV");
                BAUK::logg::simple::logg({l=>5,dump=>1}, "CHOSEN OPTIONS:", %{$optsRef});
                1;
            }
            sub parse($$$;$){
                my $optsRef = shift;
                my $commandOptsRef = shift;
                my $chosenCommands = shift;
                my %map = %{shift || {}};
                BAUK::logg::simple::logg({l=>6,dump=>1}, "GetOptsv2, parse with:", $optsRef, $commandOptsRef, $chosenCommands);
                my $currentOpts = $optsRef;
                my $argSize = $#ARGV;     # Number of args in ARGV is used at end to tell if anything changed, we shoudl re-run
                my ($options, $commands); # Temporary variables used throughout to hold the options and commands prior to calling GetOpts
                # Get all the options for each command in reverse order (base, sub1, sub2...)
                # Note: Use reverse order and do these before the main GetOptions to allow overriding
                if(@{$chosenCommands}){
                    for my $chosenNo(reverse 0..(scalar(@{$chosenCommands}) -1)){
                        my $chosen = $chosenCommands->[$chosenNo];     # Name of this sub-options
                        my ($mainAlias)       = split('\|', $chosen);  # Main alias of this sub-option (used in the given $opts hash)
                        my $chosenOptions     = $commandOptsRef;       # Used to narrow down the command-opts for this variable
                        $currentOpts = $optsRef;                       # Used to narrow fown the optsRef so we are in the right sub-opts namespace
                        BAUK::logg::simple::logg(5, "Parsing chosen sub-command: $chosen (@ARGV)");
                        for my $c(0..$chosenNo){ # Narrow down the refs into the right sub-opt namespace
                            my ($alias)       = split('\|', $chosenCommands->[$c]);
                            BAUK::logg::simple::logg(6, "Filtering down to '$alias'");
                            $chosenOptions = $chosenOptions->{$chosenCommands->[$c]};
                            if(ref $currentOpts->{$alias} eq "CODE"){
                                $currentOpts->{$alias}->();
                                $currentOpts->{$alias} = {};
                            }
                            $currentOpts->{$alias} = $currentOpts->{$alias} || {};
                            $currentOpts   = $currentOpts->{$alias};
                        }
                        ($options, $commands) = BAUK::Getopt::v2::sortOptions($chosenOptions);
                        GetOptions($currentOpts, keys(%$options));
                        # If any options have been used, restart from the bottom sub-option to ensure override works properly
                        if($#ARGV < $argSize){
                            BAUK::Getopt::v2::parse($optsRef, $commandOptsRef, $chosenCommands, \%map);
                            return;
                        }
                    }
                }
                # Do top level options
                BAUK::logg::simple::logg(5, "Parsing top level options (@ARGV)");
                ($options, $commands) = BAUK::Getopt::v2::sortOptions($commandOptsRef);
                GetOptions($optsRef, keys(%$options));
                # GetOptions($currentOpts, keys(%$options)) or exit 3;
                # Get any sub-options provided
                my $currentOptions = $commandOptsRef;
                $currentOptions = $currentOptions->{$_} for(@{$chosenCommands});
                ($options, $commands) = BAUK::Getopt::v2::sortOptions($currentOptions);
                my $opt = $ARGV[0];
                if($opt){
                    $opt =~ s/^-*//; # In case they have put dashes before sub-command
                    for my $subCommand(keys %$commands){
                        for my $alias(split('\|', $subCommand)){
                            if($alias eq $opt){
                                $currentOptions = $commands->{$subCommand};
                                push @$chosenCommands, $subCommand;
                                shift @ARGV;
                            }
                        }
                    }
                }
                # TODO: Does not do arg overrides properly - TODO: TEST: should do now (except if you have --sub2 --top --top/sub2 ...)
                # If any args used, go through again to ensure you get them from all levels
                if($#ARGV < $argSize){
                    BAUK::Getopt::v2::parse($optsRef, $commandOptsRef, $chosenCommands, \%map)
                }elsif($map{generate_completion}){
                    BAUK::Getopt::v2::loggCompletion($optsRef, $commandOptsRef, $chosenCommands, \%map);
                }elsif($map{strict}){
                    if(%$commands and $map{force_sub_commands}){
                        BAUK::Getopt::v2::printHelp($optsRef, $commandOptsRef, $chosenCommands);
                        die "        NEED TO PROVIDE A SUB-COMMAND \n\n";
                    }elsif(@ARGV and $map{force_all_args}){
                        BAUK::Getopt::v2::printHelp($optsRef, $commandOptsRef, $chosenCommands);
                        BAUK::logg::simple::logg({fg=>"red"}, "         UNKNOWN ARGUMENT : $ARGV[0]");
                        die "Unknown argument provided\n";
                    }
                }
            }
            sub printHelp($$$){
                my $optsRef = shift;
                my $commandOptsRef = shift;
                my $chosenCommands = shift;
                BAUK::logg::simple::logg({fg=>'cyan',l=>3},
                    "Options are listed below",
                    "='s are flags with parameters while :'s are flags with optional parameters",
                    "",
                );
                my $script = $0; $script =~ s#^.*/##;
                BAUK::logg::simple::logg(1, "For options, the divider signifies the type of argument:",
                        '= specifies it takes an argument.',
                        ': specifies it optionally takes an argument.',
                        '% specifies the argument is a key=value pair and you can provide it more than once.',
                        '@ specifies this argument can be passed more than once.',
                        'A blank seperator between keys (e.g. --verbose, -v) and descriptions specifies it does not take an argument.');
                BAUK::logg::simple::loggTitle({fg=>'purple'}, {title=>"OPTIONS for : ".$script." ".join(" ", @$chosenCommands), space=>15, u=>"="});
                my $currentCommand = $commandOptsRef;
                my ($options, $commands, $help) = BAUK::Getopt::v2::sortOptions($currentCommand);
                unless(@{$help}){
                    $help = [$0];
                    $help = BAUK::unc::utils::getScriptData($0)->{comments};
                }
                BAUK::Getopt::v2::printOptions2($options, $help);
                for my $command(@$chosenCommands){
                    $currentCommand = $currentCommand->{$command};
                    ($options, $commands, $help) = BAUK::Getopt::v2::sortOptions($currentCommand);
                    if(%{$options}) {
                        BAUK::logg::simple::loggTitle({fg=>'purple'}, {title=>"Options for ".$command, space=>15});
                        BAUK::Getopt::v2::printOptions2($options, $help);
                    }
                }
                if(%{$commands}){
                    BAUK::logg::simple::loggTitle({fg=>'purple'}, {title=>"Sub Commands", space=>15});
                    my $longestSub = BAUK::utils::getLongest(keys %{$commands});
                    for my $sub(sort keys %{$commands}){
                        my ($subOpts, $subCommands, $subHelp) = BAUK::Getopt::v2::sortOptions($commands->{$sub});
                        printf " +  %-${longestSub}s : %s\n", $sub, (shift @{$subHelp} || '');
                        printf "    %-${longestSub}s   %s\n", '', $_ for @{$subHelp};
                    }
                }
                print "\n";
            }
            sub addDefaultOptions($$$){
                my $optsRef = shift;
                my $commandOptsRef = shift;
                my $chosenCommands = shift;
                unless($commandOptsRef->{help}){
                    $commandOptsRef->{help}  = "Show the help menu";
                    $optsRef->{help} = sub {
                        BAUK::Getopt::v2::printHelp($optsRef, $commandOptsRef, $chosenCommands);
                        BAUK::logg::simple::logg(1, "Leftover args: @ARGV");
                        exit BAUK::definitions::error("INVALID_ARGUMENTS");
                    };
                }
                unless($commandOptsRef->{'verbose|v'} || $commandOptsRef->{'verbose'}){
                    $commandOptsRef->{'verbose|v:i'} = "Increase/Set verbose level (-v -v / -v 2)";
                    $optsRef->{'verbose'} = sub {
                        my ($argument, $value) = @_;
                        if($value){
                            BAUK::logg::simple::setLoggLevel($value);
                        }else{
                            BAUK::logg::simple::incrementLoggLevel();
                        }
                        BAUK::logg::simple::logg(5, "Logging increased to ".getLoggLevel());
                    }
                }
                unless($commandOptsRef->{'colour|color'} || $commandOptsRef->{'colour'} || $commandOptsRef->{'color'}){
                    $commandOptsRef->{'colour|color!'} = "Set logg colour output";
                    $optsRef->{colour} = sub {
                        my ($argument, $value) = @_;
                        BAUK::logg::simple::setLoggColour($value);
                    };
                }
            }
            sub sortOptions($){
                my $optionsRef = shift;
                my %options = ();
                my %commands = ();
                my @help = ();
                for my $key(keys %$optionsRef){
                    my $ref = ref $optionsRef->{$key};
                    if($ref eq "HASH"){
                        $commands{$key} = $optionsRef->{$key};
                    }elsif($key =~ /^\?/){
                        if($ref eq "ARRAY"){
                            push @help, @{$optionsRef->{$key}};
                        }else{
                            push @help, $optionsRef->{$key};
                        }
                    }else{
                        $options{$key} = $optionsRef->{$key};
                    }
                }
                # return (options=>\%options, commands=>\%commands);
                return (\%options, \%commands, \@help);
            }
            sub printOptions2($$){
                my %options = %{$_[0]};
                my @help    = @{$_[1]};
                BAUK::logg::simple::logg({fg=>'grey'}, @help, "") if(@help);
                my $OPTIONS_LENGTH = BAUK::utils::getLongest(map {join(", ", @{BAUK::Getopt::v2::getOptionsAliases($_)})} keys %options);
                $OPTIONS_LENGTH += 2;
                my @common_opts = ();
                my @opts = ();
                OUTER:
                for my $k(sort keys %options){
                    my $key = $k;
                    my $d = " ";
                    # $d = "$1$2"  if($k =~ s/([=:+])[si]?([\@%]?)$//);
                    $d = "$2$1"  if($k =~ s/([=:+])[si]?([\@%]?)$//);
                    #my @keys = map {(length($_) == 1) ? "-$_" : "--$_"} split(/\|/, $k);
                    my @keys  = @{BAUK::Getopt::v2::getOptionsAliases($key)};
                    my @lines;
                    if(ref $options{$key} eq "ARRAY"){
                        @lines = (sprintf("%${OPTIONS_LENGTH}s %2s %s", join(", ", @keys), $d, shift @{$options{$key}}));
                        if(BAUK::logg::simple::logg(1)){
                            push @lines, sprintf("%${OPTIONS_LENGTH}s    %s", "", $_) for @{$options{$key}};
                        }elsif(@{$options{$key}}){
                            $lines[$#lines] =~ s/$/ .../;
                        }
                    }else{
                        @lines = (sprintf("%${OPTIONS_LENGTH}s %2s %s", join(", ", @keys), $d, $options{$key}));
                    }
                    if(grep /^\Q$keys[0]/, @COMMON_OPTS){
                        push @common_opts, @lines;
                    }else{
                        push @opts, @lines;
                    }
                }
                if(@common_opts){
                    BAUK::logg::simple::logg($_) for @common_opts;
                    print "\n"
                }
                BAUK::logg::simple::logg($_) for @opts;
            }
            sub getOptionsAliases($){
                my $optString = shift;
                my @options = ();
                if($optString =~ /^(\w[\w\-|]*)([=!:+]?)([sif]?)([@%]?)$/){
                    @options = split(/\|/, $1);
                    my $mapping = $2;
                    my $dataType = $3;
                    my $array = $4;
                    if($mapping eq '!'){
                        if(BAUK::logg::simple::logg(1)){
                            @options = map {($_, "no$_")} @options # To do it for all
                        }else{
                            push @options, "no$options[0]" # To do it just for first one
                        }
                    }
                    @options = map { (length($_) > 1) ? "--$_" : "-$_" } @options;
                }else{
                    warn "Invalid optionsString: '$optString'";
                }
                return \@options;
            }
            sub loggCompletion($$$$) {
                my $optsRef = shift;
                my $commandOptsRef = shift;
                my $chosenCommands = shift;
                my %map = %{+shift};
                my %opts = ();
                my $currentCommand = $commandOptsRef;
                my ($options, $commands, $help) = BAUK::Getopt::v2::sortOptions($currentCommand);
                for my $opt(keys %{$options}){
                    # $opts{$_}++ for @{BAUK::Getopt::v2::getOptionsAliases($opt)};
                    $opts{BAUK::Getopt::v2::getOptionsAliases($opt)->[0]}++;
                }
                for my $command(@$chosenCommands){
                    $currentCommand = $currentCommand->{$command};
                    ($options, $commands, $help) = BAUK::Getopt::v2::sortOptions($currentCommand);
                    for my $opt(keys %{$options}){
                        # $opts{$_}++ for @{BAUK::Getopt::v2::getOptionsAliases($opt)};
                        $opts{BAUK::Getopt::v2::getOptionsAliases($opt)->[0]}++;
                    }
                }
                for my $subCommand(keys %{$commands}){
                    my ($alias) = split('\|', $subCommand);
                    # $opts{$_}++ for split('\|', $subCommand);
                    $opts{$alias}++;
                }
                print "$_\n" for sort keys %opts;
                exit;
            }
            1;
            }
            ########## use BAUK::Getopt::v2 - END   #####
        use Exporter qw(import);
        our @EXPORT    = qw(BaukGetOptions checkUserOptions BaukGetOptionsCompletion BaukGetOptions2);
        my %c = ( # c = custom
            help    => 1,
            verbose => 1,
            colour  => 1,
        );
        sub checkUserOptions($$$){ # (\%opts, \%commandOpts, |arg| or |[arg1, arg2]| or |{arg1=>"default1", arg2=>"default2"}| )
            my $optsRef         = shift;
            my $commandOptsRef  = shift;
            my $choicesRef      = shift;
            my %options         = ();
            my $ans;
            if(ref $choicesRef eq "HASH"){
                %options = %{$choicesRef};
            }elsif(ref $choicesRef eq "ARRAY"){
                $options{$_} = undef for @{$choicesRef};
            }else{
                $options{$choicesRef} = undef;
            }
            for my $opt(keys %options){
                next if($optsRef->{$opt}); # Skip if specified
                #TODO - replace with choiceany in choices if I make it
                print "You have not specified the '$opt' choice";
                for(keys %$commandOptsRef){
                    print " ($commandOptsRef->{$_})" if($_ =~ m#^$opt([\|=\$])#);
                }
                print "\n ",(($options{$opt}) ? "default($options{$opt})" : "")," : ";
                $ans = <STDIN>;
                chomp $ans;
                $optsRef->{$opt} = $ans;
            }
        }
        sub BaukGetOptions($$@){
            my $optsRef = shift;
            my $commandOptsRef = shift;
            my $commandOptsExtraRef = {};
            my %helpOpts = %$commandOptsRef;
            # Send any hashes to $commandOptsExtraRef
            # TODO: Allow nested hashes
            for(keys %{$commandOptsRef}){
                if(ref $commandOptsRef->{$_} eq "HASH"){
                    $commandOptsExtraRef->{$_} = $commandOptsRef->{$_};
                    delete $commandOptsRef->{$_};
                }
            }
            # Process any extraOpts and insert them into the hash
            if(ref $commandOptsExtraRef eq "HASH" and exists $ARGV[0]){
                my $choice = $ARGV[0];
                for (keys %$commandOptsExtraRef){
                    my @extras = split('\|', $_);
                    my $key = $extras[0];
                    if(grep /^$choice$/, @extras){
                        shift @ARGV;
                        my %extraOpts = %{$commandOptsExtraRef->{$_}};
                        for (keys %extraOpts){
                            $commandOptsRef->{$_} = $extraOpts{$_};
                        }
                        $optsRef->{$key} = 1;
                        $optsRef->{$key} = {}; # TODO
                        last;
                    }
                }
            }
            # Check for values present
            $c{$_} = 1 for(keys %c);
            for(keys(%$commandOptsRef)){
                my $key = $_; $key =~ s/[|=].*//;
                $c{help}    = 0 if($key eq "help");
                $c{verbose} = 0 if($key eq "verbose");
                $c{colour}  = 0 if($key =~ m/(no)*colou*r/);
            }
            # Add default arguments
            if($c{help}){
                $$commandOptsRef{help}  = "Show the help menu";
                $helpOpts{help}         = "Show the help menu";
                $$optsRef{help} = sub {
                    my $script = $0; $script =~ s#^.*/##;
                    BAUK::logg::simple::loggTitle({title=>"OPTIONS - for ".$script, space=>15, u=>"="});
                    printOptions(\%helpOpts, $optsRef);
                    print "\n";
                    exit BAUK::definitions::error("INVALID_ARGUMENTS");
                };
            }
            if($c{verbose}){
                $$commandOptsRef{'verbose|v'} = "Increase verbosity";
                $helpOpts{'verbose|v'}        = "Increase verbosity";
                $$optsRef{'verbose'} = sub {
                    BAUK::logg::simple::incrementLoggLevel();
                }
            }
            if($c{colour}){
                $$commandOptsRef{'colour|color'} = "Set logg colour output";
                $helpOpts{'colour|color'}        = "Set logg colour output, can be prefixed with 'no'";
                $$optsRef{colour} = sub {
                    BAUK::logg::simple::setLoggColour(1);
                };
                $$commandOptsRef{'nocolour|nocolor'} = "Stop logg colour output";
                $$optsRef{nocolour} = sub {
                    BAUK::logg::simple::setLoggColour(0);
                };
            }
            # Remove helper/info hashes ?___
            for(keys(%$commandOptsRef)){
                delete $$commandOptsRef{$_} if(m/^\?/);
            }
            Getopt::Long::Configure ("bundling_override");
            Getopt::Long::Configure ("require_order");
            GetOptions($optsRef, keys(%$commandOptsRef)) or exit 3;
            BAUK::logg::simple::logg(4, "OPTIONS PROVIDED:");
            BAUK::logg::simple::logg(4, sprintf(" - %-20s : %s", $_, $optsRef->{$_})) for keys %{$optsRef};
            1;
        }
        sub BaukGetOptionsCompletion($){
            my $map = shift;
            my $commandOptsRef  = $map->{options} || $map->{opts} || die "Need to provide an options hash to get Completion";
            my $command = $map->{command} || die "Need to provide a command";
            my @options = @{$map->{custom} || []};
            # Check for default values present
            $c{$_} = 1 for(keys %c);
            for(keys(%$commandOptsRef)){
                my $key = $_; $key =~ s/[|=].*//;
                $c{help}    = 0 if($key eq "help");
                $c{verbose} = 0 if($key eq "verbose");
                $c{colour}  = 0 if($key =~ m/(no)*colou*r/);
            }
            push @options, 'help' if $c{help};
            push @options, 'verbose', 'v' if $c{verbose};
            push @options, 'colour', 'nocolour' if $c{colour};
            for my $k (keys %{$commandOptsRef}){
                next if($k =~ /^\?/);
                my $sub = ref $commandOptsRef->{$k} eq "HASH";
                $k =~ s/=.*//;
                if($sub){
                    push @options, split('\|', $k);
                }else{
                    push @options, map {length $_ == 1 ? "-$_" : "--$_"} split('\|', $k);
                }
            }
            my $completion = "complete -o bashdefault -o default -W '".join(' ', @options)."' $command";
            return $completion;
        }
        1;
        }
        ########## use BAUK::Getopt    - END   #####
    BAUK::logg::simple::setLoggLevel(BAUK::config::getBaukConfigValue("LIB.PERL.BAUK.LOGG.BASE_VERBOSE", 0));
    BAUK::logg::simple::setLoggColour(BAUK::config::getBaukConfigValue("LIB.PERL.BAUK.LOGG.BASE_COLOUR", 0));
    1;
    }
    ########## use BAUK::main      - END   #####
    ########## use BAUK::files     - START #####
    BEGIN {
    package BAUK::files;
    use strict;
    use warnings;
    use Exporter 'import';
    our @EXPORT = qw(readFileToArrayHash readFileToHash writeToFile readFileToArray copyFile readFileToString);
    sub readFileToArrayHash($@);
    sub readFileToHash($@);
    sub writeToFile($@);
    sub readFileToArray(@);
    sub copyFile($$@){
        my $from      = shift;
        my $to        = shift;
        my $transform = shift || sub {return $_[0];};
        open my $IN,  "<$from" or die "Could not open '$from' for reading";
        open my $OUT, ">$to"   or die "Could not open '$to' for writing";
        while(my $line = <$IN>){
            my $newLine = $transform->($line);
            print $OUT $newLine;
        }
        close $IN;
        close $OUT;
    }
    sub readFileToArrayHash($@) { #  ($fileName,\@keys, \@output)
    	my $fileName = $_[0];
    	my $folderName = $fileName; $folderName =~ s|[^/]*$||;
    	my @columnNames;
    	if (exists $_[1]) {@columnNames = @{$_[1]};}
    	my @output;
    	if (exists $_[2]) {@output = @{$_[2]};}
    	#my @subData;
    	#my %subMap;
    	#my $colCount;
    	open(my $fh,"<", $fileName) or die "FILE '$fileName' NOT FOUND: ";
    	my $lineNo = 0;
    	while (my $line = <$fh>) { $lineNo++;
    		chomp $line;
    		if($lineNo == 1) {
    			if ($line =~ s/^!//){
    				@columnNames = split('\|', $line);
    				foreach (@columnNames) {
    					$_ =~ s/ *$//;
    				}
    				next;
    			}
    		}
    		my @subData   = split('\|', $line);
    		#print "@subData\n";
    		my %subMap = ();
    		my $colCount = 0;
    		foreach (@subData) {
    			$_ =~ s/ *$//;
    			if($_ =~ s/^@// == 1){
    				my @subSubData = BAUK::files::readFileToArrayHash("$folderName$_");
    				$_ = \@subSubData;
    			}
    			elsif($_ =~ s/^%// == 1){
    				my %subSubData = BAUK::files::readFileToHash("$folderName$_");
    				$_ = \%subSubData;
    			}
    			#print "$_"."#\n";
    			$subMap{$columnNames[$colCount++]} = $_;
    		}
    		push(@output,\%subMap);
    	}
    	close $fh;
    	return @output;
    }
    sub readFileToHash($@) { #  ($fileName, \@output)
    	my $fileName = $_[0];
    	my $folderName = $fileName; $folderName =~ s|[^/]*$||;
    	my %output;
    	if (exists $_[1]) {%output = %{$_[1]};}
    	open(my $fh,"<$fileName") or die "FILE '$fileName' NOT FOUND: ";
    	while (my $line = <$fh>) {
    		chomp $line;
    		my @subData   = split('\|', $line);
    		foreach (@subData) {
    			$_ =~ s/ *$//;
    			if($_ =~ s/^@// == 1){
    				my @subSubData = BAUK::files::readFileToArrayHash("$folderName$_");
    				$_ = \@subSubData;
    			}
    		}
    		$output{$subData[0]} = $subData[1];
    	}
    	close $fh;
    	return %output;
    }
    sub writeToFile($@) { #fileName, @fileData
    	my $fileName = shift;
    	open(FILE, ">$fileName") or die;
    	foreach (@_) {
    		print FILE "$_\n";
    	}
    	close FILE;
    }
    sub readFileToArray(@) { #  ($fileName, \@output)
        my $fileName = $_[0];
        my @output;
        if (exists $_[1]) {@output = @{$_[1]};}
        open(my $fh,"<$fileName") or die "FILE '$fileName' NOT FOUND: ";
        while (my $line = <$fh>) {
            chomp $line;
            push (@output, $line);
        }
        return \@output;
    }
    sub readFileToString($) { #  ($fileName)
        my $fileName = $_[0];
        my $output = '';
        open(my $fh,"<$fileName") or die "FILE '$fileName' NOT FOUND: ";
        while (my $line = <$fh>) {
            $output .= $line;
        }
        return $output;
    }
    1;
    }
    ########## use BAUK::files     - END   #####
    ########## use BAUK::logg::buffer - START #####
    BEGIN {
    package BAUK::logg::buffer;
    use strict;
    use warnings;
    use Exporter qw(import);
    our @EXPORT = qw(loggBuffer loggBufferAppend loggBufferSave loggBufferClear loggBufferEnd loggBufferInUse);
    sub loggBuffer {
        local $| = 1;
        BAUK::logg::simple::loggBuffer(@_);
    }
    sub loggBufferAppend {
        local $| = 1;
        BAUK::logg::simple::loggBufferAppend(@_);
    }
    sub loggBufferSave {
        local $| = 1;
        BAUK::logg::simple::loggBufferSave(@_);
    }
    sub loggBufferClear {
        local $| = 1;
        BAUK::logg::simple::loggBufferClear(@_);
    }
    sub loggBufferEnd {
        local $| = 1;
        BAUK::logg::simple::loggBufferEnd(@_);
    }
    sub loggBufferInUse {
        BAUK::logg::simple::loggBufferInUse(@_);
    }
    1;
    }
    ########## use BAUK::logg::buffer - END   #####
    ########## use BAUK::logg::commands - START #####
    BEGIN {
    package BAUK::logg::commands;
    use strict;
    use warnings;
        ########## use BAUK::threads   - START #####
        BEGIN {
        package BAUK::threads;
        use strict;
        use warnings;
        use threads;
        use Exporter qw(import);
        our @EXPORT = qw(executeThreads threadLoader);
        my $THREADING = 1;
        sub executeThreads($$;$){
            my $commandRef  = shift;
            #my $baseDataRef = ($#_ > 0) ? shift : ();
            my $baseDataRef = shift;
            my $dataRef     = shift;
            my @baseData    = (ref $baseDataRef eq "ARRAY") ? @{$baseDataRef} : ($baseDataRef);
            my @args        = @{$dataRef};
            my @threads     = ();
            my @return      = ();
            for(@args){
                my @data = ();
                if(ref $_ eq "ARRAY"){
                    @data = @{$_};
                }else{
                    push @data, $_;
                }
                if($THREADING){
                    if($THREADING > 1 && scalar(@threads) >= $THREADING){
                        BAUK::logg::simple::logg(6, "Running threads part: ".scalar(@threads)." threads...");
                        push @return, $_->join() for @threads;
                        @threads = ();
                    }
                    push @threads, threads->create($commandRef, @baseData, @data);
                }else{
                    push @return, $commandRef->(@data);
                }
            }
            BAUK::logg::simple::logg(6, "Joining last ".scalar(@threads)." threads...");
            push @return, $_->join() for @threads;
            return @return;
        }
        sub setThreading($){
            my $in = shift;
            if(ref $in eq 'HASH'){
                $THREADING = $in->{threads} if(defined $in->{threads});
            }else{
                $THREADING = $in;
            }
        }
        sub threadLoader($);
        sub threadLoader($){
            my $in          = shift;
            return BAUK::threads::threadLoader({sub=>$in}) if(ref $in eq "CODE");
            my $sub         = delete($in->{sub}) || delete($in->{until}) or die "Need to provide a sub to execute";
            my @args        = @{(delete($in->{args}) || [])};
            my $safe        = (defined $in->{safe})  ? delete($in->{safe})  : 1;
            my $logLevel    = (defined $in->{level}) ? delete($in->{level})  : 3;
            # TODO: this does not help as the sub traps all the input anyway
            #if(BAUK::logg::simple::getLoggLevel() > $logLevel){
            #    return $sub->(@args);
            #}
            my ($thr)       = threads->create($sub, @args);
            BAUK::logg::loggLoader::loggLoader({until=>sub{$thr->is_running()}, %{$in}});
            if($thr->is_running()){
                if($safe){
                    warn "Ctrl+C again to abandon thread.\n";
                    BAUK::logg::loggLoader::loggLoader({until=>sub{$thr->is_running()}, %{$in}});
                }
                if($thr->is_running()){
                    warn "Killed while thread was still running.\n";
                    #$thr->kill('KILL')->detach(); # Produces warnings unless kill specified in thread
                    $thr->detach();
                    return;
                }
            }
            return $thr->join();
        }
        1;
        }
        ########## use BAUK::threads   - END   #####
    use Exporter qw(import);
    our @EXPORT = qw(loggExec);
    sub loggExec($){
        my $in = shift;
        my $command = delete($in->{command}) || delete($in->{c}) || die "Need to provide a command to Execute";
        my $level   = (defined $in->{level})  ? delete($in->{level})  : 2;
        my $die     = (defined $in->{die})    ? delete($in->{die})    : 1;
        my $status  = (defined $in->{status}) ? delete($in->{status}) : 1;
        my $logs    = (defined $in->{logs})   ? delete($in->{logs})  : 0; # Whether to return just logs
        my %status;
        my $sub;
        if(ref($command) eq 'CODE'){
            $sub = $command;
        }else{
            if($command =~ /;/){
                $command =~ s#\\#\\\\#g;
                $command =~ s#"#\\"#g;
                $command = "sh -c \"$command\"";
            }
            $command .= " 2>&1";
            $command .= " | tee /dev/tty && exit \${PIPESTATUS[0]}" if(BAUK::logg::simple::logg($level));
            $sub = sub {BAUK::bauk::execute($command)};
        }
        if(BAUK::logg::simple::logg($level)){
            BAUK::logg::simple::logg(0, "loggExec: $in->{logg}") if($in->{logg});
            %status = $sub->();
        }else{
            my %loaderOpts = (
                spinner => "cradle",
                %{$in},
                sub     => $sub
            );
            if($status){
                $loaderOpts{newline} = 0;
            }
            %status = BAUK::threads::threadLoader(\%loaderOpts);
        }
        if($status{exit} and $die){
            BAUK::logg::extra::loggDie("FAILED",
                "COMMAND: $command",
                "EXIT   : $status{exit}",
                "LOG    : ", @{$status{log}}
            );
        }elsif($status and $status{exit}){
            BAUK::logg::simple::loggAppend({fg=>"red"}, "FAILED");
        }elsif($status){
            BAUK::logg::simple::loggAppend({fg=>"green"}, "SUCCESS");
        }
        return @{$status{log}} if $logs;
        return %status;
    }
    1;
    }
    ########## use BAUK::logg::commands - END   #####
    ########## use BAUK::errors    - START #####
    BEGIN {
    package BAUK::errors;
    use strict;
    use warnings;
    use Exporter qw(import);
    our @EXPORT = qw(addError addWarning addInfo checkErrors checkWarnings showErrors dieIfErrors htmlErrors);
    my  $REMOVE_ERRORS   = 0;
    my  $REMOVE_WARNINGS = 0;
    our $GLOBAL_OBJECT   = BAUK::errors->new();
    sub checkErrors;
    sub showErrors;
    sub addError($){
        BAUK::errors::addItem("error", @_);
    }
    sub addWarning($){
        BAUK::errors::addItem("warning", @_);
    }
    sub addInfo($){
        BAUK::errors::addItem("info", @_);
    }
    sub checkErrors(){
        my $self = shift || $GLOBAL_OBJECT;
        return 1 if(@{$self->{types}->{error}->{items}});
        return 0;
    }
    sub checkWarnings {
        my $self = shift || $GLOBAL_OBJECT;
        return 1 if(@{$self->{types}->{warning}->{items}} or $self->checkErrors());
        return 0;
    }
    sub showErrors {
        my $self = shift || $GLOBAL_OBJECT;
        my $errors = 0;
        for my $type($self->getTypes()){
            for (@{$self->{types}->{$type}->{items}}){
                print uc($type).": $$_{message}\n";
            }
        }
        if(not($self->checkWarnings())){
            print "No Errors found\n";
        }else{
            print "Total ${_}s: ".scalar(@{$self->{types}->{$_}->{items}}).". " for($self->getTypes());
            print "\n";
        }
        return 2 if($self->checkErrors());
        return 1 if($self->checkWarnings());
        return 0;
    }
    sub htmlErrors {
        my $self = shift || $GLOBAL_OBJECT;
        # TODO: Move some of this into logg so you can log in html (would also want to add a return option to not logg but return logg)
        my @html = ();
        push @html, "<p>ERRORS</p>";
        my $errors = 0;
        for my $type(keys %{$self->{types}}){
            push @html, "<p>${type}s<br/>";
            for (@{$self->{types}->{$type}->{items}}){
                push @html, " - $$_{message} </br>";
            }
            push @html, "</p>";
        }
        if(not(BAUK::errors::checkWarnings())){
            push @html, "No Errors found</br>";
        }else{
            push @html, "Total ${_}s: ".scalar(@{$self->{types}->{$_}->{items}}).". </br>" for(keys %{$self->{types}});
        }
        push @html, "</br>";
        return @html;
    }
    sub dieIfErrors {
        my $self = shift || $GLOBAL_OBJECT;
        if($self->checkErrors()){
            $self->showErrors();
            exit 1;
        }
    }
    sub error {
        my $self = shift;
        $self->add("error", @_);
    }
    sub add {
        my $self = shift;
        my $type = shift;
        my $message = shift;
        my $item = (ref $message eq "HASH") ? $message : {message => $message};
        push @{$self->{types}->{$type}->{items}}, $item;
    }
    sub getTypes {
        my $self = shift;
        return keys %{$self->{types}};
    }
    sub addErrorObject {
        my $self = (scalar(@_) == 1) ? $GLOBAL_OBJECT : shift;
        my $obj  = shift;
        for my $type(keys %{$obj->{types}}){
            if(defined $self->{types}->{$type}){
                push(@{$self->{types}->{$type}->{items}}, $_) for(@{$obj->{types}->{$type}->{items}});
            }else{
                $self->{types}->{$type} = $obj->{types}->{$type};
            }
        }
    }
    sub addItem {
        my $self = (scalar(@_) == 2) ? $GLOBAL_OBJECT : shift;
        my $type = shift;
        my $message = shift;
        my $item = (ref $message eq "HASH") ? $message : {message => $message};
        push @{$self->{types}->{$type}->{items}}, $item;
    }
    sub setupData {
        my $data = shift;
        $data->{types} = {
            error => {items=>[]},
            warning => {items=>[]},
            info => {items=>[]},
        };
        return $data;
    }
    sub new {
        my $class = shift;
        my $data = shift || {};
        die "Need to provide hash to new <TEMPLATE>" unless($data);
        die "Provided data must be a hash" unless(ref $data eq "HASH");
        my $self = BAUK::errors::setupData($data);
        bless $self, $class;
        return $self;
    }
    1;
    }
    ########## use BAUK::errors    - END   #####
use Cwd qw[abs_path];
use JSON;
# # # # # # #  CONFIG
my %commandOpts     = (
# --verbose and --help from BAUK::main->BaukGetOptions()
    'update|u'                  => "To update tags",
    'force|f'                   => "",
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
BAUK::logg::simple::logg(0, "Downloading versions...");
# TODO Do all curls in parallel as it saves time
my @dockerhub_tags = @{BAUK::bauk::executeOrDie("curl --silent -f -lSL https://index.docker.io/v1/repositories/bauk/git/tags")->{log}};
my @git_versions = @{BAUK::bauk::executeOrDie('curl -sS https://mirrors.edge.kernel.org/pub/software/scm/git/|sed -n "s#.*git-\([0-9\.]\+\).tar.gz.*#\1#p"|sort -V')->{log}};
@dockerhub_tags = map { $_->{name} } @{$JSON->decode(join('', @dockerhub_tags))};
BAUK::logg::simple::logg(3, @dockerhub_tags);
BAUK::logg::simple::logg(2, @git_versions);
my $latest_version = $git_versions[-1];
if(@ARGV){
    for my $v(@ARGV){
        unless(grep /^$v$/, @git_versions){
            BAUK::logg::extra::loggDie("Version not found: $v");
        }
    }
    @git_versions = @ARGV;
}
if($opts{reverse}){
    @dockerhub_tags = reverse @dockerhub_tags;
    @git_versions   = reverse @git_versions;
}
BAUK::logg::simple::logg(0, "Latest version: $latest_version. Total versions: ".($#git_versions+1));
updateLatest($latest_version);
updateDocs();
for my $dir(@{$opts{dir}}){
    $dir =~ s#/*$##;
    doDir({dir => $dir, versions => \@git_versions, max_updates => $opts{max}});
}
pushTags();


BAUK::errors::dieIfErrors();
BAUK::logg::simple::logg(0, "SCRIPT FINISHED SUCCESFULLY");
# # # # # # # # # # # # # # #  MAIN-END # # # # # # # # # # # # # # #

# # # # # # #  SUBS
sub setup(){
    BAUK::Getopt::v2::BaukGetOptions2(\%opts, \%commandOpts) or die "UNKNOWN OPTION PROVIDED";
    if($opts{"minus-pending-from-max"}){
        my %statuses = %{getDockerhubBuildStatuses()};
        my $pending = $statuses{"In progress"} + $statuses{"Pending"};
        $opts{max} -= $pending;
    }
    if($opts{max}){
        BAUK::logg::simple::logg(0, "MAX TAGS TO UPDATE: $opts{max}");
    }else{
        BAUK::logg::extra::loggDie("MAX TAGS TO UPDATE IS 0. EXITING EARLY.");
    }
}
sub doVersion {
    my $in = shift;
    # BAUK::logg::simple::loggBufferAppend("DOING VERSION");
    BAUK::logg::simple::loggBufferSave();
    my $version = $in->{version} || die "TECHNICAL ERROR";
    my $dir = $in->{dir} || die "TECHNICAL ERROR";

    if($opts{force}){
        BAUK::logg::simple::logg(0, "Forcing to update");
        updateTag($in);
        return;
    }
    BAUK::bauk::executeOrDie("sed -i 's/ARG VERSION=.*/ARG VERSION=$version/' $dir/Dockerfile-*");
    if($in->{last_working_minor} and $version =~ /^$in->{last_working_minor}/){
        BAUK::logg::simple::logg(0, "Assuming it will work as minor worked: $in->{last_working_minor}");
    }elsif($in->{last_broken_minor} and $version =~ /^$in->{last_broken_minor}/){
        BAUK::logg::simple::logg(0, "Assuming it will NOT work as minor did not: $in->{last_broken_minor}");
    }else{
        for my $dockerfile(glob "$dir/Dockerfile-*"){
            BAUK::logg::simple::logg(0, "Doing version: $version ($dockerfile)");
            my %exec = BAUK::bauk::execute("cd $dir && docker build . --file $dockerfile --tag git_tmp");
            if($exec{exit} != 0){
                BAUK::logg::simple::logg(0, "Buid failed");
                $in->{last_broken_minor} = $version;
                $in->{last_broken_minor} =~ s/^([^0-9]*\.[^0-9]*).*/$1/;
                return;
            }
            my @log = @{BAUK::bauk::executeOrDie("docker run --rm -it git_tmp --version")->{log}};
            unless(grep $version, @log){
                BAUK::logg::simple::logg(0, "Buid corrupt somehow");
                $in->{last_broken_minor} = $version;
                $in->{last_broken_minor} =~ s/^([^0-9]*\.[^0-9]*).*/$1/;
                return 1;
            }
            BAUK::logg::simple::logg(0, "Build success");
        }
        BAUK::logg::simple::logg(0, "All builds successfull");
    }
    updateTag($in);
}
sub doDir {
    my $in = shift;
    my $dir = $in->{dir} || die "TECHNICAL ERROR";
    my @versions = @{$in->{versions} || die "TECHNICAL ERROR"};
    my $max_updates = $in->{max_updates} || die "TECHNICAL ERROR";
    # Ignore Dockerfiles-Builds as if the base build changes, we need it to build first before rebuilding the final image
    my $parent_commit = BAUK::bauk::executeOrDie("git log -n1 --pretty=%h origin/master -- '$dir' ':!$dir/*test.yml' ':!$dir/hooks'")->{log}->[0];
    $in->{parent_commit} = $parent_commit;

    my $tag_prefix = $dir eq "app" ? "" : "$dir/";
    my @ALL_TAGS = @{BAUK::bauk::executeOrDie("git tag")->{log}};
    my $count = 0;
    my $total = $#versions +1;
    for my $version(@versions){
        $count ++;
        my $version_tag = "${tag_prefix}${version}";
        my $docker_tag;
        BAUK::logg::simple::loggBuffer(sprintf("%2s/%3s/%3s) %-10s:", $UPDATE_TAGS, $count, $total, $version));
        
        if($UPDATE_TAGS >= $max_updates){
            BAUK::logg::simple::loggBuffer("Reached max tags to update ($max_updates)");
            BAUK::logg::simple::loggBufferSave();
            return;
        }
        if($version =~ /^0/){
            BAUK::logg::simple::loggBufferAppend("Skipping dev version");
            next;
        }
        if(grep /^$version_tag$/, @ALL_TAGS){
            BAUK::logg::simple::logg(2, "Version exists: $version_tag");
            $in->{last_working_minor} = $version;
            $in->{last_working_minor} =~ s/^([^0-9]*\.[^0-9]*).*/$1/;
            my $tag_parent = BAUK::bauk::executeOrDie("git show --pretty=%b -s $version_tag | sed -n 's/^PARENT: //p'")->{log}->[0];
            if($tag_parent eq $parent_commit){
                if($dir eq "app"){
                    $docker_tag = "centos-${version}-${parent_commit}";
                }elsif($dir eq "build"){
                    # Builds do not care about the parent commit, they are just compilation images
                    $docker_tag = "centos-$dir-${version}";
                }else{
                    $docker_tag = "centos-$dir-${version}-${parent_commit}";
                }
                if($opts{"update-unbuilt"} && ! grep /^${docker_tag}$/, @dockerhub_tags){
                    BAUK::logg::simple::loggBufferAppend("RETAGGING TO REBUILD");
                    doVersion({%{$in}, version => $version});
                }else{
                    BAUK::logg::simple::loggBufferAppend("SKIPPING - up to date");
                    next;
                }
            }elsif($opts{update}){
                BAUK::logg::simple::loggBufferAppend("UPDATING due to new commits");
                BAUK::logg::simple::logg(3, "$tag_parent..$parent_commit");
                doVersion({%{$in}, version => $version});
            }else{
                BAUK::logg::simple::loggBufferAppend("SKIPPING - pass -u flag to update");
            }
        }else{
            BAUK::logg::simple::logg(0, "New version: $version_tag");
            doVersion({%{$in}, version => $version});
        }
    }
    BAUK::logg::simple::loggBufferEnd();
}
sub updateTag {
    my $in = shift;
    my $version = $in->{version};
    my $dir = $in->{dir};
    my $tag_prefix = $dir eq "app" ? "" : "$dir/";
    BAUK::bauk::executeOrDie("git reset origin/master");
    BAUK::bauk::executeOrDie("sed -i 's/ARG VERSION=.*/ARG VERSION=$version/' $dir/Dockerfile-*");
    BAUK::bauk::executeOrDie("git add -- $dir/Dockerfile-*");
    BAUK::bauk::executeOrDie("git commit --allow-empty -m 'AUTOMATIC COMMIT FOR $version' -m 'PARENT: $in->{parent_commit}'");
    BAUK::bauk::executeOrDie("git tag -f ${tag_prefix}$version");
    pushTag("${tag_prefix}$version");
    $in->{last_working_minor} = $version;
    $in->{last_working_minor} =~ s/^([^0-9]*\.[^0-9]*).*/$1/;
}
sub pushTags {
    return unless $opts{group};
    if($UPDATE_TAGS){
        BAUK::logg::simple::logg(0, "Updating tags");
        if(BAUK::choices::choiceYN("You have $UPDATE_TAGS tags to update. Update them [y/n]? :")){
            BAUK::bauk::executeOrDie("git push --tags --force")
        }else{
            BAUK::logg::simple::logg(0, "Reverting tags...");
            BAUK::bauk::executeOrDie("git fetch --tags --force");
        }
    }
}
sub updateDocs {
    my $docs_commit = BAUK::bauk::executeOrDie("git log -n1 --pretty=%H origin/master -- 'README*' 'DocsDockerfile'")->{log}->[0];
    my $last_docs_commit = BAUK::bauk::executeOrDie("git rev-parse refs/tags/docs")->{log}->[0];
    if($docs_commit ne $last_docs_commit){
        BAUK::logg::simple::logg(0, "Updating docs: $last_docs_commit -> $docs_commit");
        BAUK::bauk::executeOrDie("git tag -f docs '$docs_commit'");
        pushTag("docs");
    }else{
        BAUK::logg::simple::logg(0, "Docs up to date: $docs_commit");
    }
}
sub pushTag {
    my $tag = shift;
    $UPDATE_TAGS += 1;
    BAUK::bauk::executeOrDie("git push -f origin $tag 2>&1") unless $opts{group};
}
sub prepareRepo {
    BAUK::bauk::executeOrDie("git fetch --prune");
    BAUK::bauk::executeOrDie("git fetch --prune --tags --force");
    BAUK::bauk::executeOrDie("git checkout origin/master 2>&1");
}
sub updateLatest {
    my $latest_version = shift;
    my @log = @{BAUK::bauk::executeOrDie("git tag --list latest -n1")->{log}};
    if(grep /VERSION: $latest_version$/, @log){
        BAUK::logg::simple::logg(0, "Latest up to date: '$latest_version'");
    }else{
        BAUK::logg::simple::logg(0, "Updating latest version to '$latest_version'");
        BAUK::bauk::executeOrDie("git tag -f latest 4b825dc642cb6eb9a060e54bf8d69288fbee4904 -m 'VERSION: $latest_version'");
        BAUK::bauk::executeOrDie("git push -f origin latest:refs/tags/latest");
    }
}
sub getDockerhubBuildStatuses {
    my $max_items = 50;
    my $token = BAUK::files::readFileToString("$SCRIPT_DIR/dockerhub_token");
    chomp $token;
    my %exec = BAUK::logg::commands::loggExec({logg => "Fetching Dockerhub builds", command =>"curl -sS --compressed --fail"
        ." 'https://hub.docker.com/api/audit/v1/action/?include_related=true&limit=${max_items}&object=%2Fapi%2Frepo%2Fv1%2Frepository%2Fbauk%2Fgit%2F'"
        ." -H 'Accept: application/json'"
        ." -H 'Content-Type: application/json'"
        ." -H 'Cookie: token=$token'"});
    my @builds = @{$JSON->decode(join("", @{$exec{log}}))->{objects}};
    my %statuses = ();
    for(@builds){
        $statuses{$_->{state}}++;
    }
    BAUK::logg::simple::logg(0, "Last $max_items builds: ", $JSON->encode(\%statuses));
    return \%statuses;
}

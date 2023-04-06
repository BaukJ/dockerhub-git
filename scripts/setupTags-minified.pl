#!/usr/bin/env perl
# BAUK_OPT:COMPLETION=1
{ # MODULES START
    { ##### IMPORTED MODULE: BAUK::Utils::functions
        package BAUK::Utils::functions;
        use strict;
        use warnings;
        use Carp;
        use Exporter 'import';
        our @EXPORT_OK = qw(validateArguments);
        my $CHOICEYN_DEFAULT = "";
        my $CHOICEYN_AUTO    = 0;
        1;
        sub validateErrorMessage {
            my $allowedOptions = shift;
            my @errors = @{+shift};
            my $extraOpts = shift || {};
            $extraOpts->{depth} ||= 1;
        
            my @functionCaller = (caller($extraOpts->{depth}));
            my @callingCaller = (caller(1 + $extraOpts->{depth}));
            my @callingParentCaller = (caller(2 + $extraOpts->{depth})); # Used to get method that failed
        
            my $validatingFunction = $callingCaller[3] ? "$callingCaller[3]()" : "$functionCaller[1]:$functionCaller[2]";
            my $callingFunction = defined($callingParentCaller[0]) ? $callingParentCaller[3] : "main script";
            my $callingLine = "$callingCaller[1]:$callingCaller[2]";
            die(map{"$_\n"} ("\n\nAllowed options:",
                map({
                        "- ".join('/', ($_, @{$allowedOptions->{$_}->{aliases} || []}))
                            ." : $allowedOptions->{$_}->{description}".($allowedOptions->{$_}->{ref} ? " [$allowedOptions->{$_}->{ref}]" : "");
                    } sort keys %{$allowedOptions}),
                "Invalid arguments:",
                map({" - $_"} @errors),
                "Script Error in $callingFunction\[$callingLine]. Invalid arguments passed to $validatingFunction\n"));
        }
        sub validateArguments {
            my $allowedOptions = shift;
            my $givenArgs = shift;
            my $extraOpts = delete($allowedOptions->{_opts}) || {};
            my @errors = ();
        
            croak "validateArguments() needs to be passed a hash of allowed options as 1st parameter" if(ref($allowedOptions) ne 'HASH');
            push @errors, "Only one argument expected" if $_[0];
            if(ref($givenArgs) ne 'HASH'){
                push @errors, "This function expects a hash as an input";
                $givenArgs = {}; # To allow other checks to proceed
            }
        
            my %aliasMappings = ();
            for my $optionKey(keys %{$allowedOptions}){
                $allowedOptions->{$optionKey}->{description} ||= '';
                for my $alias(@{$allowedOptions->{$optionKey}->{aliases} || []}){
                    croak "Script error. Duplicate alias passed to validateArguments()" if $aliasMappings{$alias} or $allowedOptions->{$alias};
                    $aliasMappings{$alias} = $optionKey;
                }
            }
            for my $arg(sort keys %{$givenArgs}){
                my $option;
                if($allowedOptions->{$arg}){
                    $option = $allowedOptions->{$arg};
                }elsif($aliasMappings{$arg}){
                    $givenArgs->{$aliasMappings{$arg}} = $givenArgs->{$arg};
                    $option = $allowedOptions->{$aliasMappings{$arg}};
                }else{
                    push @errors, "Unknown argument passed: '$arg'";
                    next;
                }
                push @errors, "Invalid argument type for '$arg'. Received '".ref($givenArgs->{$arg})."' but expected '".$option->{ref}."'"
                    if($option->{ref} and $option->{ref} ne ref($givenArgs->{$arg}));
                push @errors, "Invalid argument for '$arg'. Received '".$givenArgs->{$arg}."' did not match regex: '".$option->{regex}."'"
                    if($option->{regex} and $givenArgs->{$arg} !~ /$option->{regex}/);
                for my $mEx(@{$option->{mutuallyExclusive} || []}){
                    push @errors, "'$arg' cannot be used with the '$mEx' option." if($givenArgs->{$mEx});
                }
            }
            for my $optionKey(keys %{$allowedOptions}){
                $givenArgs->{$optionKey} = $allowedOptions->{$optionKey}->{default} if(defined($allowedOptions->{$optionKey}->{default}) and not defined $givenArgs->{$optionKey});
            }
        
            validateErrorMessage($allowedOptions, \@errors, $extraOpts) if(@errors);
            return $givenArgs;
        }
    }
    { ##### IMPORTED MODULE: BAUK::definitions
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
    { ##### IMPORTED MODULE: BAUK::Utils
        package BAUK::Utils;
        use strict;
        use warnings;
        use Exporter qw(import);
        our @EXPORT     = qw(getLargest getLongest setHash);
        our @EXPORT_OK  = qw(unique);
        sub unique(@){
            do { my %seen; grep { !$seen{$_}++ } @_ };
        }
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
    { ##### IMPORTED MODULE: BAUK::unc::utils
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
            my $file = shift or die "TECHNICAL ERROR: getScriptData() needs to provide a filename";
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
    { ##### IMPORTED MODULE: BAUK::time
        package BAUK::time;
        use strict;
        use warnings;
        BAUK::Utils::functions->import( qw[validateArguments]);
        use Exporter qw(import);
        our @EXPORT    = qw(dateTimeStamp dateStamp timeStamp);
        our @EXPORT_OK = qw(dateHash);
        sub dateHash {
            my %map = (
                time => time,
                pad  => undef,
                %{+shift || {}},
            );
            my @t = localtime($map{time});
            $t[4] += 1;     # Month adjustment
            $t[5] += 1900;  # Year  adjustment
            my $return = {
                seconds  => $t[0],
                minutes  => $t[1],
                hours    => $t[2],
                monthday => $t[3],
                month    => $t[4],
                year     => $t[5],
                weekday  => $t[6],
                yearday  => $t[7],
            };
            if(defined($map{pad})){
                $return->{seconds}  = sprintf("%$map{pad}2s", $return->{seconds});
                $return->{minutes}  = sprintf("%$map{pad}2s", $return->{minutes});
                $return->{hours}    = sprintf("%$map{pad}2s", $return->{hours});
                $return->{monthday} = sprintf("%$map{pad}2s", $return->{monthday});
                $return->{month}    = sprintf("%$map{pad}2s", $return->{month});
                $return->{year}     = sprintf("%$map{pad}4s", $return->{year});
                $return->{weekday}  = sprintf("%$map{pad}1s", $return->{weekday});
                $return->{yearday}  = sprintf("%$map{pad}3s", $return->{yearday});
            }
            return $return;
        }
        sub dateTimeStamp {
            my $time = time;
            my $delim = "_";
            if(defined($_[0])){
                if(ref($_[0]) eq "HASH"){
                    my %opts = %{validateArguments({
                        delimiter => {description=>"Delimiter to use detween date and time",aliases=>[qw[delim]]},
                        time      => {description=>"What time object to use, defaults to now (time)",aliases=>[qw[]]},
                    }, @_)};
                    $time = $opts{time} if defined $opts{time};
                    $delim = $opts{delimiter} if $opts{delimiter};
                }else{
                    $time = $_[0];
                }
            }
            return dateStamp($time).$delim.timeStamp($time);
        }
        sub timeStamp {
            my $time = defined($_[0]) ? $_[0] : time;
            my @t = localtime($time);
            $t[4] += 1;     # Month adjustment
            $t[5] += 1900;  # Year  adjustment
            my @times_used = reverse @t[0..5];
            return sprintf("%02s%02s%02s", @times_used[3..5]);
        }
        sub dateStamp {
            my $time = defined($_[0]) ? $_[0] : time;
            my @t = localtime($time);
            $t[4] += 1;     # Month adjustment
            $t[5] += 1900;  # Year  adjustment
            my @times_used = reverse @t[0..5];
            return sprintf("%04s%02s%02s", @times_used[0..2]);
        }
        1;
    }
    { ##### IMPORTED MODULE: BAUK::files
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
        
            open my $IN,  "<", $from or die "Could not open '$from' for reading: $!";
            open my $OUT, ">", $to   or die "Could not open '$to' for writing: $!";
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
        
        
        	open(my $fh,"<", $fileName) or die "Cannot open file '$fileName': $!";
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
        		my %subMap = ();
        		my $colCount = 0;
        		foreach (@subData) {
        			$_ =~ s/ *$//;
        			if($_ =~ s/^@// == 1){
        				my @subSubData = readFileToArrayHash("$folderName$_");
        				$_ = \@subSubData;
        			}
        			elsif($_ =~ s/^%// == 1){
        				my %subSubData = readFileToHash("$folderName$_");
        				$_ = \%subSubData;
        			}
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
        
        	open(my $fh, "<", $fileName) or die "Cannot open file '$fileName': $!";
        	while (my $line = <$fh>) {
        		chomp $line;
        
        		my @subData   = split('\|', $line);
        		foreach (@subData) {
        			$_ =~ s/ *$//;
        			if($_ =~ s/^@// == 1){
        				my @subSubData = readFileToArrayHash("$folderName$_");
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
        	open(FILE, ">", $fileName) or die "Cannot write to '$fileName': $!";
        	foreach (@_) {
        		print FILE "$_\n";
        	}
        	close FILE;
        }
        
        sub readFileToArray(@) { #  ($fileName, \@output)
            my $fileName = $_[0];
            my @output;
            if (exists $_[1]) {@output = @{$_[1]};}
            open(my $fh,"<", $fileName) or die "Cannot open file: '$fileName': $!";
            while (my $line = <$fh>) {
                chomp $line;
                push (@output, $line);
            }
            return \@output;
        }
        
        sub readFileToString($) { #  ($fileName)
            my $fileName = $_[0];
            my $output = '';
            open(my $fh,"<", $fileName) or die "FILE '$fileName' NOT FOUND: $!";
            while (my $line = <$fh>) {
                $output .= $line;
            }
            return $output;
        }
        
        
        1;
    }
    { ##### IMPORTED MODULE: BAUK::logg::simple
        package BAUK::logg::simple;
        BAUK::time->import();
        BAUK::Utils::functions->import( qw[validateArguments]);
        use Cwd qw[cwd];
        use File::Path qw[make_path];
        use strict;
        use warnings;
        my $USE_BEFFER = 1; # If we end up using libraries in the future
        my $DEFAULT_LOG_DIR = "$ENV{HOME}/.bauk/log";
        use Exporter qw(import);
        our @EXPORT = qw(logg setLoggLevel addLoggFile setLoggColour getLoggColour incrementLoggLevel loggTitle getLoggLevel loggAppend loggColour);
        my $VERBOSE = 0;
        my $COLOUR  = 1;
        my @opts = (
            {name => "verbose", key => "verbose|v+", desc => "Incremental argument for verbosity"},
        );
        my %LOGFILES = ();
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
                logg($format, $line);
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
            if(ref $i eq 'HASH'  or  $i =~ m/^[0-9><=+!]*[0-9]+$/){
                return 1;
            }
            return 0;
        }
        sub _transformInput {
            my $input = shift || {};
            my $extraOpts = shift || {};
            if(ref $input ne 'HASH'){
                $input = {level => $input};
            }
            return validateArguments({
                "level"         => {description=>"Level required to log",aliases=>[qw[l]],  default=>0},
                "foreground"    => {description=>"Foreground colour",aliases=>[qw[colour fg]]},
                "background"    => {description=>"Background colout",aliases=>[qw[bg]]},
                "special"       => {description=>"Any text special effects",aliases=>[qw[s]]},
                "dump"          => {description=>"Basic data dumper",aliases=>[qw[d]]},
                "format"        => {description=>"Set as 0 to suporess formatting such as newlines",aliases=>[qw[f]],  default=>1},
                "type"          => {description=>"",aliases=>[qw[t]]},
                stderr          => {description=>"Whether to print to STDERR instead of normal STDOUT",aliases=>[qw[STDERR]]},
                "returnMessage" => {description=>"To not logg but return the string that would get logged. (1=Just return,2=Log and return)",aliases=>[qw[return]], default => 0},
                %{$extraOpts},
                _opts           => {depth => 2},
            }, $input);
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
            logg(4, "No lines given to logg (Input: $input)") unless @_;
            my $opts = ();
            if(ref $input eq "HASH"){
                $opts = _transformInput($input);
                $LEVEL  = $opts->{level};
                $format = $opts->{format};
                $dump   = $opts->{dump};
                $type   = $opts->{type};
                if(_containsKey($opts, qw[foreground background special])){
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
                $opts = _transformInput({});
                $LEVEL = $input;
                $colour = 0;
                $format = 1;
            }
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
            my $logFiles = 0;
            unless($opts->{returnMessage} == 1){
                for my $logFile(sort keys %LOGFILES){
                    if(logIt({verbose=>($LOGFILES{$logFile}->{verbose} || $VERBOSE),level=>$LEVEL,offset=>$LOGFILES{$logFile}->{offset}})){
                        open $LOGFILES{$logFile}->{fh}, ">>", $LOGFILES{$logFile}->{file} or die "Could not open log file '$logFile'";
                        $logFiles++;
                    }
                }
            }
            my $loggScreen = logIt({level=>$LEVEL});
            if($loggScreen or $logFiles){
                for(@_){
                    $message .= _levelPrefix($LEVEL)  if($format);
                    $message .= $colour               if($COLOUR and $colour);
                    $message .= " "                   if($format);
                    if($dump){
                        $message .= loggDump($_);
                    }else{
                        $message .= $_;
                    }
                    $message .= "\033[0m"     if($COLOUR and $colour);
                    $message .= "\n"          if($format);
                }
                unless($opts->{returnMessage} == 1){
                    if(@BUFFER and $loggScreen){
                        _clearLine();
                    }
                    if($opts->{stderr}){
                        print STDERR $message if $loggScreen;
                    }else{
                        print $message if $loggScreen;
                    }
                    for my $logFile(sort keys %LOGFILES){
                        print { $LOGFILES{$logFile}->{fh} } $message if $LOGFILES{$logFile}->{fh};
                    }
                    if(@BUFFER and $loggScreen){
                        print $BUFFER[0];
                    }
                }
            }
            for my $logFile(sort keys %LOGFILES){
                close $LOGFILES{$logFile}->{fh} if $LOGFILES{$logFile}->{fh};
                delete $LOGFILES{$logFile}->{fh};
            }
            return $message if $opts->{returnMessage};
            return logIt({level=>$LEVEL});
        }
        sub loggColour {
            my $opts;
            if(inputWasPassed @_){
                $opts = _transformInput(shift);
            }else{
                $opts = {};
            }
            for my $logg(@_){
                for my $subLogg(split(/(<%[a-z]*%.*?%>)/, $logg)){
                    next unless $subLogg;
                    if($subLogg =~ s/<%([a-z]*)%(.*?)%>/$2/){
                        logg({%{$opts}, f=>0, fg=>$1}, $subLogg);
                    }else{
                        logg({%{$opts}, f=>0}, $subLogg);
                    }
                }
                logg($opts, ""); # To add newlines if they were asked for
            }
        }
        sub loggAppend {
            if(@BUFFER){
                loggBufferAppend(@_);
            }else{
                logg(@_);
            }
        }
        sub _loggBuffer {
            my $in = shift;
            my %opts = %{_transformInput($in->{opts} || {}, {
                bufferUntil     => {default=>1, description => "At this logg level, stop buffering # TODO: allow different levels passed"},
            })};
            $opts{format} = 0; # Stop newlines getting appended for buffering
            $opts{level}  = 0; # Only allow buffers of level 0 at the moment
            $opts{returnMessage} = 2; # Need to return the message as well as printing to screen
        
            my $line = defined($in->{logg}) ? $in->{logg} : '';
            if(defined $BUFFER[0] and not $in->{append}){
                if(logIt({level=>$opts{bufferUntil}})){
                    print "\n";
                }else{
                    _clearLine();
                }
            }
            my @oldBuffer = @BUFFER;
            @BUFFER = ();
            my %loggOpts = %opts;
            delete $loggOpts{bufferUntil}; # Delete any buffer-only opts
            my $message = logg(\%loggOpts, $line);
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
            my $in = parseBufferInput(@_);
            $in->{append} ||= 1;
            _loggBuffer($in);
        }
        sub loggBuffer {
            my $in = parseBufferInput(@_);
            _loggBuffer($in);
        }
        sub loggBufferInUse {
            return 1 if(@BUFFER);
            return 0;
        }
        sub loggBufferClear {
            if(@BUFFER){
                _clearLine();
                @BUFFER = ();
            }else{
                logg(6, "WARNING: Tried clearing buffer, but nothing in buffer to clear");
            }
        }
        sub loggBufferSave {
            if(@BUFFER){
                print "\n";
                @BUFFER = ();
            }else{
                logg(6, "WARNING: Tried saving buffer, but nothing in buffer to save");
            }
        }
        sub loggBufferEnd {
            if(logIt({level=>1})){
                loggBufferSave();
            }else{
                loggBufferClear();
            }
        }
        sub logIt {
            my $in = shift;
            my $verbose = $in->{verbose};
               $verbose = $VERBOSE unless(defined $verbose);
            my $level   = $in->{level};
            my $offset  = $in->{offset} || 0;
            $verbose += $offset;
        
            my $logIt = 0;
            if($level =~ /^[0-9]+$/ or $level =~ s/>=([0-9]+)$/$1/ or $level =~ s/=>([0-9]+)$/$1/){
                $logIt = 1 if($verbose >= $level);
            }elsif($level =~ s/^<([0-9]+)$/$1/){
                $logIt = 1 if($verbose < $level);
            }elsif($level =~ s/^=+([0-9]+)$/$1/){
                $logIt = 1 if($verbose == $level);
            }elsif($level =~ s/^>([0-9]+)$/$1/){
                $logIt = 1 if($verbose > $level);
            }elsif($level =~ s/^!=([0-9]+)$/$1/){
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
                return "[".join(",", map{loggDump($_)} @{$p})."]";
            }else{
                return $p;
            }
        }
        sub loggTest(){
            print "\n\n\n\n\n\n\n\n\n\n";
            for(0..5){
                $VERBOSE = $_;
                print "LOG LEVEL SET TO $VERBOSE:\n";
                logg($_, "Logging with a level of $_/5") for(0..5);
            }
            print "---\n";
            for(sort keys %foregrounds){
                logg({fg => $_, l=>1}, "Logging in the colour $_");
            }
            print "---\n";
            for(sort keys %backgrounds){
                logg({bg => $_}, "Logging with a background colour $_");
            }
            print "---\n";
            for(sort keys %specials){
                logg({special => $_}, "Logging with special $_");
            }
            print "---\n";
            logg({type=>"diff"}, "Testing the 'diff' type...", "- File x/y/z", "  lines...", "> Added this line", "< Removed this line", "  lines...");
            print "---\n";
            loggBuffer("TESTING BUFFER");
            for(1..5){
                select undef, undef, undef, 0.2;
                loggBufferAppend(".");
            }
            loggBufferSave();
        }
        sub loggTitle($;$) {
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
        	logg($loggRef, $title);
            logg($loggRef, $underTitle);
        }
        sub loggUsage(){
            die "TODO: not yet implemented";
        }
        sub addLoggFile {
            my $name = shift or die "Need to privide a name for logg file";
            my $logFileOpts = shift || {};
            my $scriptName = $0; $scriptName =~ s#.*/##;
            $logFileOpts->{file} ||= "$ENV{HOME}/.bauk/logs/$scriptName/$name";
            $logFileOpts->{file} = cwd . "/" . $logFileOpts->{file} unless $logFileOpts->{file} =~ m#^/#;
            $logFileOpts->{file} .= '-'.dateTimeStamp() if $logFileOpts->{timestamp};
            $logFileOpts->{file} .= '.log';
            logg(3, "Using log file: '$logFileOpts->{file}'");
            warn "Overwriting previous log file: $name" if $LOGFILES{$name};
            $LOGFILES{$name} = $logFileOpts;
            my $logDir = $logFileOpts->{file};
            $logDir =~ s#[^/\\]*$##;
            make_path $logDir;
            if(-f $logFileOpts->{file} and not $logFileOpts->{append}){
                unlink $logFileOpts->{file};
            }
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
                eval '($wchar, $hchar, $wpixels, $hpixels) = GetTerminalSize();';
                $SCREEN_WIDTH = $wchar unless $@;
            }
        }else{
            logg(6, "WARNING: Not attached to a terminal so not buffering");
        }
        1;
    }
    { ##### IMPORTED MODULE: BAUK::JsonFile
        package BAUK::JsonFile;
        use strict;
        use warnings;
        use JSON;
        BAUK::logg::simple->import();
        use Exporter qw(import);
        our @EXPORT = qw();
        sub getAll {
            my $self = shift;
            return $self->{data};
        }
        sub get {
            my $self = shift;
            my $key = shift;
            return $self->{data}->{$key};
        }
        sub set {
            my $self = shift;
            my $key = shift;
            my $value = shift;
            $self->{data}->{$key} = $value;
            return $self;
        }
        sub setAll {
            my $self = shift;
            my $data = shift;
            die "data needs to be a hash" unless ref $data eq "HASH";
            $self->{data} = $data;
            return $self;
        }
        sub load {
            my $self = shift;
            my $opts = shift || {};
            if(-f $self->{file}){
                open my $fh, "<", $self->{file} or die "$!";
                $self->{data} = $self->{json}->decode(join("",<$fh>));
                close $fh;
            } else {
                logg(6, "JsonFile: '$self->{file}' missing");
                unless((not defined $opts->{ignoreMissing} and $self->{ignoreMissing}) or $opts->{ignoreMissing}){
                    die "Cannot load Json file as it does not exist: '$self->{file}'";
                }
                $self->{data} = {};
            }
            return $self;
        }
        sub save {
            my $self = shift;
            open my $fh, ">", $self->{file} or die "$!";
            print $fh $self->{json}->encode($self->{data});
            close $fh;
            return $self;
        }
        sub setupConfig($){
            my $config = shift;
            if(defined $config->{data} and ref $config->{data} ne "HASH"){
                die "data provided to JsonFile must be a hash";
            }else{
                $config->{data} ||= {};
            }
            die "Need to provide 'file' to JsonFile" unless $config->{file};
            $config->{pretty} ||= 0;
            $config->{json} ||= JSON->new()->pretty($config->{pretty});
            return $config;
        }
        sub new {
            my $class = shift;
            my $config = shift;
            die "Need to provide hash to new <TEMPLATE>" unless($config);
            die "Provided config must be a hash" unless(ref $config eq "HASH");
        
            my $self = setupConfig($config);
            bless $self, $class;
            return $self;
        }
        1;
    }
    { ##### IMPORTED MODULE: BAUK::logg::loggLoader
        package BAUK::logg::loggLoader;
        use strict;
        use warnings;
        use Term::ReadKey;
        BAUK::logg::simple->import();
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
        
            logg({l=>4,dump=>1}, "Starting loadingLine", "- time", $time, "- spinner", \%spinner);
        
            if($logg){
                logg({level=>0,format=>0}, sprintf("%-${pad}s", $logg));
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
                loggAppend({level=>0,format=>0,colour=>"yellow"}, sprintf(" (%3ss)", $endTime - $startTime));
            }
            print "\n" if $newline;
            while(ReadKey(-1)){};
            ReadMode 0;
        }
        
        1;
    }
    { ##### IMPORTED MODULE: BAUK::logg::buffer
        package BAUK::logg::buffer;
        use strict;
        use warnings;
        BAUK::logg::simple->import();
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
    { ##### IMPORTED MODULE: BAUK::shell
        package BAUK::shell;
        use strict;
        use warnings;
        BAUK::logg::simple->import();
        use Exporter qw(import);
        our @EXPORT = qw(execute executeOrDie executeOrManual);
        sub execute($){
            my $command = shift;
            logg(6, "EXECUTING COMMAND: $command");
            my @log = `$command`;
            my $exit = $? >> 8;
            chomp for @log;
            s/\r$// for @log;
            logg(7, "COMMAND RETURNED ($exit): ", @log);
            return {log => \@log, exit => $exit};
        }
        sub executeOrDie($){
            my $command = shift;
            my $ret = execute($command);
            if($ret->{exit}){
                die "Command failed $ret->{exit}: $command
                Log: ".join("\n", @{$ret->{log}});
            }
            return $ret;
        }
        sub executeOrManual($){
            my $command = shift;
            my $ret = execute($command);
            if($ret->{exit}){
                logg({fg=>"red"}, "Command failed: $command",
                    map {"LOG: $_"} @{$ret->{log}},
                    "Entering shell now, once finished manually fixing the problem, hit Ctrl+D");
                `bash 1>&2`;
                logg({fg=>"red"}, "Hit enter to continue...");
                <STDIN>;
            }
            return $ret;
        }
        
        1;
    }
    { ##### IMPORTED MODULE: BAUK::logg::extra
        package BAUK::logg::extra;
        use strict;
        use warnings;
        BAUK::logg::simple->import();
        use Exporter qw(import);
        our @EXPORT = qw(loggDie loggWarn);
        sub loggDie {
            my ($hash, @logg) = getHashAndLogg({fg => "red", stderr => 1}, @_);
            logg($hash, map {"ERROR: $_"} @logg);
            die "\n";
        }
        sub loggWarn {
            my ($hash, @logg) = getHashAndLogg({fg => "orange", stderr => 1}, @_);
            logg($hash, map {"WARN : $_"} @logg);
        }
        sub getHashAndLogg {
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
    { ##### IMPORTED MODULE: BAUK::bauk
        package BAUK::bauk;
        use strict;
        use warnings;
        BAUK::logg::simple->import();
        use Carp;
        use Exporter qw(import);
        our @EXPORT = qw(execute executeOrDie vim perl makeDirs touchFile unique);
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
            logg(6, "EXECUTING COMMAND: $command");
            my @log = `$command`;
            my $exit = $? >> 8;
            chomp for @log;
            s/\r$// for @log;
            logg(7, "COMMAND RETURNED ($exit): ", @log);
            return (log => \@log, exit => $exit);
        }
        sub executeOrDie($){
            my $command = shift;
            my %ret = execute($command);
            if($ret{exit}){
                croak "Command failed $ret{exit}: $command
                Log: ".join("\n", @{$ret{log}});
            }
            return \%ret;
        }
        sub vim(@){
            my $exit = system(vim => @_);
            die "Vim failed with code: $exit" if($exit != 0);
        }
        sub perl($@){
            my $file = shift @_;
            my $return = system($^X, "$file", @_);
            logg(1, "PERL RETURNED: $return");
            return $return;
        }
        sub makeDirs(@){
            for (@_){
                if(-d "$_"){
                    logg(1, "~~~ Dir already exists '$_'");
                }else{
                    mkdir "$_" or die "Could not create folder: $_: $!";
                    logg(1, "~~~ Created dir '$_'");
                }
            }
        }
        1;
    }
    { ##### IMPORTED MODULE: BAUK::choices
        package BAUK::choices;
        use strict;
        use warnings;
        BAUK::bauk->import();
        BAUK::logg::extra->import();
        BAUK::Utils->import();
        BAUK::Utils::functions->import( qw[validateArguments]);
        use Carp;
        use Term::Complete;
        use Term::ReadKey;
        use Exporter 'import';
        our @EXPORT    = qw(choice choiceN choiceYN);
        our @EXPORT_OK = qw(readTerm);
        my $CHOICEYN_DEFAULT = "";
        my $CHOICEYN_AUTO    = 0;
        1;
        sub readTerm {
            my $opts        = shift || {};
            validateArguments({
                    prompt    => { description => "What to print to the screen before user input" },
                    secret    => { description => "Whether to hide the users input" },
                    multiLine => { description => "To change into multiLine mode, allowing multiple input lines" },
                    default   => { description => "Default value if an empty string is provided by user" },
                    choices   => { description => "Generates help menu and actions. Each item can have: description,action", ref => "HASH" },
                    completion=> { description => "Enables and provide a list for completion. Once enabled, also grabs items from \%choices if specified.", ref => "ARRAY", mutuallyExclusive => ["secret", "multiLine"]},
                }, $opts);
            my $secret      = $opts->{secret} || 0;
            my $prompt      = defined($opts->{prompt}) ? $opts->{prompt} : '';
            my $multiLine   = $opts->{multiLine} || 0;
            my $default     = exists($opts->{default}) ? $opts->{default} : undef;
            my @allowed     = @{$opts->{allowed} || []};
            my %choices     = %{$opts->{choices} || {}};
            my @completion  = @{$opts->{completion} || []};
        
            if(%choices){
                $choices{'?'} ||= {
                    description => ["Show this help screen"],
                    action => sub {
                        my $longest = getLongest(map { $_->{name} } values %choices);
                        print STDERR "\n";
                        if($opts->{completion}){
                            print STDERR "COMPLETION ENABLED: Tab to complete and Ctrl+D to see available options (Ctrl+C is disabled)\n\n";
                        }
                        for my $choice(sort { $choices{$a}->{name} cmp $choices{$b}->{name} } keys %choices){
                            printf STDERR "  %-${longest}s : %s\n", $choices{$choice}->{name}, $choices{$choice}->{description}->[0] || '';
                            for my $i(1..$#{$choices{$choice}->{description}}){
                                printf STDERR "  %-${longest}s   %s\n", '', $choices{$choice}->{description}->[$i] || '';
                            }
                        }
                        readTerm($opts);
                    },
                };
                for my $choice(keys %choices){
                    croak "Invalid choice type provided ".ref($choice).": '$choice'" if(ref($choice) ne '');
                    $choices{$choice}->{name} ||= $choices{$choice}->{values} ? "<$choice>" : $choice;
                    $choices{$choice}->{description} = ref($choices{$choice}->{description}) eq 'ARRAY' ? $choices{$choice}->{description} : [$choices{$choice}->{description} || ()];
                    $choices{$choice}->{completion} ||= $choices{$choice}->{values} ? [map { ref($_) eq '' ? $_ : () } @{$choices{$choice}->{values}}] : [$choice] if $opts->{completion};
                }
            }
            push(@completion, map { @{$_->{completion}} } values %choices) if $opts->{completion};
            if(defined $opts->{prompt}){
                if(%choices){
                    my @chars = ();
                    my @long  = ();
                    my @show  = ();
                    for my $choice(sort keys %choices){
                        if(length($choice) == 1){
                            push @chars, $choice;
                        }elsif(length($choice) > 1){
                            push @long, $choice;
                        } # Ignore empty/default
                    }
                    push @show, @chars;
                    if($#long <= 3){
                        push @show, @long 
                    }else{
                        push @show, '...';
                    }
                    $prompt .= " (".join("/", @show).")";
                }
                $prompt .= " [$default]" if $default;
                $prompt .= ": ";
                $prompt .= "MULTI-LINE INPUT (Leave a blank line to finish input)\n" if $multiLine;
            }
            ReadMode('noecho') if($secret);
            my $read = '';
            if($multiLine){
                print STDERR "$prompt";
                select()->flush();
                while(my $line = <STDIN>){
                    print $line unless -t STDOUT;
                    chomp $line;
                    if($read){
                        $read .= "\n$line";
                    }else{
                        $read = $line;
                    }
                    last if(length($line) == 0);
                }
            }else{
                if($opts->{completion}){
                    $read = Term::Complete::Complete($prompt, @completion);
                }else{
                    print STDERR "$prompt";
                    select()->flush();
                    $read = <STDIN>;
                    print $read unless -t STDOUT;
                    chomp $read;
                }
            }
            if($secret){
                ReadMode('restore');
                print STDERR "\n"; # To add newline normally achieved through Enter Key
            }
            $read = $default if(defined($default) and $read eq '');
            if(%choices){
                my $found = 0;
                OUTER:
                for my $choice(sort keys %choices){
                    for my $value(@{$choices{$choice}->{values} || [$choice]}){
                        if(ref($value) eq 'Regexp'){
                            if($read =~ /$value/){
                                $found = $choices{$choice};
                                last OUTER;
                            }
                        }elsif(ref($value) eq ''){
                            if($read eq $value){
                                $found = $choices{$choice};
                                last OUTER;
                            }
                        }else{
                            croak "Invalid value type provided: ".ref($value).": '$value'";
                        }
                    }
                }
                if($found){
                    $found->{action}->($read) if($found->{action});
                }else{
                    print STDERR "Invalid value provided. Try again (? for help).\n";
                    readTerm($opts);
                }
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
                    select()->flush();
                    $ans = <STDIN>;
                    print $ans unless -t STDOUT;
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
            my $show    = 1;
            die "Need to specify options for choice!" unless @_;
            if (ref $_[0] eq 'HASH'){
                %choices = %{$_[0]};
                $default = delete $choices{default} if exists $choices{default};
                $custom  = delete $choices{"*"}     if exists $choices{"*"};
                $show    = delete $choices{show}    if defined $choices{show};
            }else{
                @choices = @_;
                if ($choices[0] eq ""){ shift @choices; $default = shift @choices;}
            }
        
            my $choicesMessage = sub {
                my $mL = getLongest(keys %choices, @choices);
                my $ret = "\nChoices ";
                $ret .= "(* = default [$default])" if(defined $default);
                $ret .= ": \n";
                if(defined $default){
                    $ret .= "  * $default \n" if (@choices);
                    $ret .= sprintf("  * %-${mL}s : %s\n", $default, $choices{$default}) if(%choices);
                }
                $ret .= "  - $_\n" for (@choices);
                for (keys %choices) {
                    next if(defined($default) and $default eq $_);
                    $ret .= sprintf("  - %-${mL}s : %s\n", $_, $choices{$_});
                }
                $ret .= sprintf("  - %-${mL}s : $custom\n", "") if($custom);
                return $ret;
            };
            my $readTermOpts = {default => $default};
            $readTermOpts->{prompt} = $choicesMessage->()."$question" if($show);
            while (1){
                my $choice = readTerm($readTermOpts);
                $ans = $choice  if($custom);
                $ans = $default if (defined($default) and uc($choice) eq uc($default));
                foreach my $i(@choices, keys %choices){
                    $ans = $i if ($choice eq $i);
                }
                last if defined $ans;
                foreach my $i(@choices, keys %choices){
                    $ans = $i if (uc($choice) eq uc($i));
                }
                last if defined $ans;
                $readTermOpts->{prompt} = $choicesMessage->()."$question" unless $readTermOpts->{prompt};
                print STDERR "Incorrect input '$choice'. Try again: ";
            }
            return $ans;
        }
        sub choiceN(@) { # (max) || (min,max)
            my($min ,$max, $default);
            if(ref($_[0]) eq "HASH"){
                my $in = shift;
                $min     = delete($in->{min}) if defined($in->{min});
                $max     = delete($in->{max}) if defined($in->{max});
                $default = delete($in->{default}) if defined($in->{default});
                die "Invalid argspassed to choiceN: ".join(", ", keys %{$in}) if(%{$in});
            }elsif($#_ == 0){
                $min = 0;
                $max = shift;
            }elsif($#_ == 1){
                $min = shift;
                $max = shift;
            }elsif($#_ == -1){
            }else{
                die "You can only pass (), (max) or (min,max) to choiceN";
            }
        
            while (1){
                my $choice = readTerm();
                if($choice eq '' and defined $default){
                    return $default;
                }elsif($choice !~ m/^-?[0-9]+$/) {
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
    { ##### IMPORTED MODULE: BAUK::logg
        package BAUK::logg;
        use strict;
        use warnings;
        BAUK::Utils->import();
        BAUK::logg::simple->import();
        BAUK::logg::extra->import();
        use Exporter qw(import);
        our @EXPORT = qw(logg setLoggLevel setLoggColour getLoggColour incrementLoggLevel loggTitle getLoggLevel loggColour
            loggDie loggWarn
        );
        1;
    }
    { ##### IMPORTED MODULE: BAUK::errors
        package BAUK::errors;
        use strict;
        use warnings;
        BAUK::logg->import();
        use Exporter qw(import);
        our @EXPORT = qw(addError addWarning addInfo checkErrors checkWarnings showErrors dieIfErrors htmlErrors);
        my  $REMOVE_ERRORS   = 0;
        my  $REMOVE_WARNINGS = 0;
        our $GLOBAL_OBJECT   = BAUK::errors->new();
        sub checkErrors;
        sub showErrors;
        sub addError($){
            addItem("error", @_);
        }
        sub addWarning($){
            addItem("warning", @_);
        }
        sub addInfo($){
            addItem("info", @_);
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
            if(not(checkWarnings())){
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
        
            my $self = setupData($data);
            bless $self, $class;
            return $self;
        }
        1;
    }
    { ##### IMPORTED MODULE: BAUK::threads
        package BAUK::threads;
        use strict;
        use warnings;
        use threads;
        BAUK::logg->import();
        BAUK::logg::buffer->import();
        BAUK::logg::loggLoader->import();
        BAUK::Utils::functions->import( qw[validateArguments]);
        eval "use Thread::Queue;";
        my $USE_THREADS = $@ ? 0 : 1;
        use Exporter qw(import);
        our @EXPORT = qw(executeWorkers executeThreads threadLoader);
        my $THREADING = 1;
        sub queueWrapper {
            my $queue      = shift;
            my $commandRef = shift;
            my @commonArgs = @{+shift};
            while(defined(my $item = $queue->dequeue_nb())){
                $commandRef->(@commonArgs, $item);
            }
            return 0;
        }
        sub executeWorkers {
            die "Cannot execute Workers as could not load Thread::Queue." unless($USE_THREADS);
            my $in = validateArguments({
                command     => {description => "The sub to run", ref => "CODE"},
                args        => {description => "The list of args to pass to each thread. One thread for each arg here.", ref => "ARRAY"},
                commonArgs  => {description => "Any arguments that should be passed as the first arguments to each thread", ref => "ARRAY", default => []},
                progress    => {description => "Whether to show progress to the screen"},
            }, @_);
            my @commonArgs  = (ref $in->{commonArgs} eq "ARRAY") ? @{$in->{commonArgs}} : ($in->{commonArgs});
            my $commandRef  = $in->{command};
            my @args        = @{$in->{args}};
            my $total       = scalar(@{$in->{args}});
            if($THREADING){
                my $queue = Thread::Queue->new();
                $queue->enqueue(@args);
                my @threads = ();
                logg(0, "Creating $THREADING threads...");
                for(1..$THREADING){
                    push @threads, threads->create(\&queueWrapper, $queue, $commandRef, \@commonArgs);
                }
                logg(0, "Created $THREADING threads...");
                while(@threads or $queue->pending()){
                    die $queue->pending()." items left to process but all threads died!" unless(@threads);
                    if(not $threads[0]->is_running()){
                        $threads[0]->join();
                        shift @threads;
                    }else{
                        loggBuffer(($total - $queue->pending())."/$total") if $in->{progress};
                        sleep 1;
                    }
                }
                $_->join() for @threads;
            }else{
                my $count = 0;
                for(@args){
                    $count++;
                    loggBuffer("$count/$total") if $in->{progress};
                    $commandRef->(@commonArgs, $_);
                }
            }
        }
        sub executeThreads {
            my $in = validateArguments({
                command     => {description => "The sub to run", ref => "CODE"},
                args        => {description => "The list of args to pass to each thread. One thread for each arg here.", ref => "ARRAY"},
                commonArgs  => {description => "Any arguments that should be passed as the first arguments to each thread", ref => "ARRAY", default => []},
                progress    => {description => "Whether to show progress to the screen"},
            }, @_);
            my $commandRef  = $in->{command};
            my @commonArgs  = (ref $in->{commonArgs} eq "ARRAY") ? @{$in->{commonArgs}} : ($in->{commonArgs});
            my @args        = @{$in->{args}};
            my @threads     = ();
            my @return      = ();
            my $total       = scalar(@args);
        
            my $count = 0;
            for(@args){
                $count++;
                loggBuffer("$count/$total") if $in->{progress};
                my @data = ($_);
                if($THREADING){
                    if($THREADING > 1 && scalar(@threads) >= $THREADING){
                        logg(6, "Running threads part: ".scalar(@threads)." threads...");
                        push @return, $_->join() for @threads;
                        @threads = ();
                    }
                    push @threads, threads->create($commandRef, @commonArgs, @data);
                }else{
                    push @return, $commandRef->(@data);
                }
            }
        
            logg(6, "Joining last ".scalar(@threads)." threads...");
            push @return, $_->join() for @threads;
        
            return @return;
        }
        sub setThreading {
            my $in = validateArguments({
                threads => {description => "How many threads to use", regex => '^[0-9]+$'}
            }, shift);
            $THREADING = $in->{threads};
        }
        sub threadLoader;
        sub threadLoader {
            my $in          = shift;
            return threadLoader({sub=>$in}) if(ref $in eq "CODE");
            my $sub         = delete($in->{sub}) || delete($in->{until}) or die "Need to provide a sub to execute";
            my @args        = @{(delete($in->{args}) || [])};
            my $safe        = (defined $in->{safe})  ? delete($in->{safe})  : 1;
            my $logLevel    = (defined $in->{level}) ? delete($in->{level})  : 3;
        
            my ($thr)       = threads->create($sub, @args);
            loggLoader({until=>sub{$thr->is_running()}, %{$in}});
            if($thr->is_running()){
                if($safe){
                    warn "Ctrl+C again to abandon thread.\n";
                    loggLoader({until=>sub{$thr->is_running()}, %{$in}});
                }
                if($thr->is_running()){
                    $thr->detach();
                    die "Killed while thread was still running.\n";
                }
            }
            return $thr->join();
        }
        1;
    }
    { ##### IMPORTED MODULE: BAUK::Getopt::v2
        package BAUK::Getopt::v2;
        use strict;
        use warnings;
        use Getopt::Long;
        BAUK::logg::simple->import();
        BAUK::logg::extra->import();
        BAUK::Utils->import();
        BAUK::logg::simple->import();
        BAUK::definitions->import();
        BAUK::choices->import( qw[readTerm]);
        BAUK::unc::utils->import( qw[getScriptData]);
        use Carp qw[croak];
        use YAML;
        use Exporter qw(import);
        our @EXPORT = qw(BaukGetOptions2);
        my @COMMON_OPTS = qw[--help --verbose --colour --nocolour --config-file];
        sub parse($$$;$);
        sub sortOptions($);
        sub BaukGetOptions2 {
            my $optsRef = shift or croak "Need to provide opts to BaukGetOptions2()";        # Ref that will get the chosen options given to it
            my $commandOptsRef = shift or croak "Need to provide commandOptsRef to BaukGetOptions2()"; # Hash of the available options and sub-options (with descriptions in values)
            my %map = %{shift || {}};   # Extra options
            my $chosenCommands = [];    # Array that will contain all the sub-options the user has chosen
            my $dashesPassed = 0;
            croak "Too many options passed to BaukGetOptions2()" if(@_);
        
            %map = (
                strict              => 1,
                force_sub_commands  => 1,   # To force the use of sub-commands if they exist
                force_all_args      => 1,   # To force all arguments to be read, if any are left, the script errors
                %map
            );
        
            addDefaultOptions($optsRef, $commandOptsRef, $chosenCommands);
            Getopt::Long::Configure("bundling_override");
            Getopt::Long::Configure("require_order");
            Getopt::Long::Configure("pass_through");
        
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
                $optsRef = {};
            }
        
            parse($optsRef, $commandOptsRef, $chosenCommands, \%map);
        
            push @ARGV, '--' if(@ARGV and $dashesPassed); # If not all options parsed, add back in -- (Will only occur if strict turned off)
            push @ARGV, @args;
            logg(4, "Leftover args: @ARGV");
            logg({l=>5,dump=>1}, "CHOSEN OPTIONS:", %{$optsRef});
            1;
        }
        sub parse($$$;$){
            my $optsRef = shift;
            my $commandOptsRef = shift;
            my $chosenCommands = shift;
            my %map = %{shift || {}};
        
            logg({l=>6,dump=>1}, "GetOptsv2, parse with:", $optsRef, $commandOptsRef, $chosenCommands);
        
            my $currentOpts = $optsRef;
            my $argSize = $#ARGV;     # Number of args in ARGV is used at end to tell if anything changed, we shoudl re-run
            my ($options, $commands); # Temporary variables used throughout to hold the options and commands prior to calling GetOpts
        
            if(@{$chosenCommands}){
                for my $chosenNo(reverse 0..(scalar(@{$chosenCommands}) -1)){
                    my $chosen = $chosenCommands->[$chosenNo];     # Name of this sub-options
                    my $chosenOptions     = $commandOptsRef;       # Used to narrow down the command-opts for this variable
                    $currentOpts = $optsRef;                       # Used to narrow fown the optsRef so we are in the right sub-opts namespace
        
                    logg(5, "Parsing chosen sub-command: $chosen (@ARGV)");
                    for my $c(0..$chosenNo){ # Narrow down the refs into the right sub-opt namespace
                        my ($alias)       = split('\|', $chosenCommands->[$c]);
                        logg(6, "Filtering down to '$alias'");
                        $chosenOptions = $chosenOptions->{$chosenCommands->[$c]};
                        if(ref $currentOpts->{$alias} eq "CODE"){
                            $currentOpts->{$alias}->();
                            $currentOpts->{$alias} = {};
                        }
                        $currentOpts->{$alias} = $currentOpts->{$alias} || {};
                        $currentOpts   = $currentOpts->{$alias};
                    }
                    parseOptions($currentOpts, $chosenOptions, $chosenCommands);
        
                    if($#ARGV < $argSize){
                        parse($optsRef, $commandOptsRef, $chosenCommands, \%map);
                        return;
                    }
                }
            }
        
            logg(5, "Parsing top level options (@ARGV)");
            parseOptions($optsRef, $commandOptsRef, $chosenCommands);
        
            my $currentOptions = $commandOptsRef;
            $currentOptions = $currentOptions->{$_} for(@{$chosenCommands});
            ($options, $commands) = sortOptions($currentOptions);
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
        
        
            if($#ARGV < $argSize){
                parse($optsRef, $commandOptsRef, $chosenCommands, \%map);
            }elsif($map{generate_completion}){
                loggCompletion($optsRef, $commandOptsRef, $chosenCommands, \%map);
            }elsif($map{strict}){
                if(%$commands and $map{force_sub_commands}){
                    printHelp($optsRef, $commandOptsRef, $chosenCommands);
                    die "        NEED TO PROVIDE A SUB-COMMAND \n\n";
                }elsif(@ARGV and $map{force_all_args}){
                    printHelp($optsRef, $commandOptsRef, $chosenCommands);
                    logg({fg=>"red"}, "         UNKNOWN ARGUMENT : $ARGV[0]");
                    die "Unknown argument provided\n";
                }
            }
        
            parseExtras($optsRef, $commandOptsRef, $chosenCommands);
            if(@{$chosenCommands}){
                for my $chosenNo(reverse 0..(scalar(@{$chosenCommands}) -1)){
                    my $chosen = $chosenCommands->[$chosenNo];     # Name of this sub-options
                    my $chosenOptions     = $commandOptsRef;       # Used to narrow down the command-opts for this variable
                    $currentOpts = $optsRef;                       # Used to narrow fown the optsRef so we are in the right sub-opts namespace
        
                    for my $c(0..$chosenNo){ # Narrow down the refs into the right sub-opt namespace
                        my ($alias)       = split('\|', $chosenCommands->[$c]);
                        $chosenOptions = $chosenOptions->{$chosenCommands->[$c]};
                        $currentOpts   = $currentOpts->{$alias};
                    }
                    parseExtras($currentOpts, $chosenOptions, $chosenCommands);
                }
            }
        }
        sub parseOptions($$$){
            my $optsRef = shift;
            my $commandOptsRef = shift;
            my $chosenCommands = shift;
            my ($options, $commands) = sortOptions($commandOptsRef);
            GetOptions($optsRef, keys(%$options)) or getOptionsError($optsRef, $commandOptsRef, $chosenCommands);
        }
        sub parseExtras($$$){
            my $optsRef = shift;
            my $commandOptsRef = shift;
            my $chosenCommands = shift;
            my @sortOptions = sortOptions($commandOptsRef);
            my ($options, $commands, $extraOpts) = @sortOptions[0, 1, 3];
            for my $opt(keys %{$options}){
                my ($mainAlias) = split('\|', $opt);
                $mainAlias =~ s/[:=!+].*//;
                my $value       = $options->{$opt};
                next unless(ref($value) eq 'ARRAY' and $value->[0] and ref $value->[0] eq 'HASH');
                my $map = $value->[0];
                if(not defined($optsRef->{$mainAlias})){
                    if($map->{prompt}){
                        loggWarn("Seperate entries with comma(,). e.g. a,b,c") if($opt =~ /\@$/);
                        loggWarn("Seperate entries with comma(,), value with '='. e.g. a=1,b=2") if($opt =~ /\%$/);
                        $optsRef->{$mainAlias} = readTerm({
                            prompt    =>$map->{prompt},
                            default   =>$map->{default},
                            multiLine =>$map->{multiLine},
                            secret    =>$map->{secret},
                        });
                        if($opt =~ /\@$/){
                            $optsRef->{$mainAlias} = [split(/, */, $optsRef->{$mainAlias})];
                        }elsif($opt =~ /%$/){
                            my %hash = map { /^(.*?)=(.*)$/ or loggDie("Invalid input"); ($1, $2) } split(/, */, $optsRef->{$mainAlias});
                            $optsRef->{$mainAlias} = \%hash;
                        }
                    }elsif(defined($map->{default})){
                        logg(3, "Setting default option for: '$opt' to '$map->{default}'");
                        $optsRef->{$mainAlias} = $map->{default};
                    }elsif($map->{required}){
                        getOptionsError($optsRef, $commandOptsRef, $chosenCommands, "You did not pass required option: $mainAlias");
                    }
                }
                if($map->{onlyif} and $optsRef->{$mainAlias}){
                    my ($onlyIfAlias) = split('\|', $map->{onlyif});
                    if(not $optsRef->{$onlyIfAlias}){
                        getOptionsError($optsRef, $commandOptsRef, $chosenCommands, "You cannot pass $mainAlias unless you also specify $map->{onlyif}");
                    }
                }
                if($map->{notif} and $optsRef->{$mainAlias}){
                    my ($notIfAlias) = split('\|', $map->{notif});
                    if($optsRef->{$notIfAlias}){
                        getOptionsError($optsRef, $commandOptsRef, $chosenCommands, "You cannot pass $mainAlias as well as $map->{notif}");
                    }
                }
                if($map->{options} and defined($optsRef->{$mainAlias}) and not grep({$optsRef->{$mainAlias} eq $_ } @{$map->{options}})){
                    getOptionsError($optsRef, $commandOptsRef, $chosenCommands, "$mainAlias only accepts the following options: \n - ".join("\n - ", @{$map->{options}}));
                }
                if($map->{action} and defined($optsRef->{$mainAlias})){
                    logg(6, "Running action for option '$opt'");
                    $map->{action}->($optsRef->{$mainAlias}, {opts => $optsRef});
                    delete $map->{action};
                };
            }
            if($extraOpts->{action}){
                logg(6, "Running action for nested command");
                $extraOpts->{action}->($optsRef);
                delete $extraOpts->{action};
            }
        }
        sub printHelp($$$){
            my $optsRef = shift;
            my $commandOptsRef = shift;
            my $chosenCommands = shift;
        
            my $script = $0; $script =~ s#^.*/##;
            if(logg(1)){
                logg({fg=>"grey"}, "For options, the divider signifies the type of argument:",
                        '= specifies it takes an argument.',
                        ': specifies it optionally takes an argument.',
                        '% specifies the argument is a key=value pair and you can provide it more than once.',
                        '@ specifies this argument can be passed more than once.',
                        'A blank seperator between keys (e.g. --verbose, -v) and descriptions specifies it does not take an argument.',
                        'Default values are specified in square brackets',
                        'Required values are denoted by the * at the start of the description',
                        '');
            }else{
                logg({fg=>"grey"}, "Run with -v before --help for information about the help menu");
            }
            loggTitle({fg=>'purple'}, {title=>"OPTIONS for : ".$script." ".join(" ", @$chosenCommands), space=>15, u=>"="});
            my $currentCommand = $commandOptsRef;
            my ($options, $commands, $help) = sortOptions($currentCommand);
            unless(@{$help}){
                $help = [$0];
                $help = getScriptData($0)->{comments};
            }
            printOptions2($options, $help);
            for my $command(@$chosenCommands){
                $currentCommand = $currentCommand->{$command};
                ($options, $commands, $help) = sortOptions($currentCommand);
                if(%{$options}) {
                    loggTitle({fg=>'purple'}, {title=>"Options for ".$command, space=>15});
                    printOptions2($options, $help);
                }
            }
            if(%{$commands}){
                loggTitle({fg=>'purple'}, {title=>"Sub Commands", space=>15});
                my $longestSub = getLongest(keys %{$commands});
                for my $sub(sort keys %{$commands}){
                    my ($subOpts, $subCommands, $subHelp) = sortOptions($commands->{$sub});
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
                    printHelp($optsRef, $commandOptsRef, $chosenCommands);
                    logg(1, "Leftover args: @ARGV");
                    exit error("INVALID_ARGUMENTS");
                };
            }
            unless($commandOptsRef->{'verbose|v'} || $commandOptsRef->{'verbose'}){
                $commandOptsRef->{'verbose|v:i'} = "Increase/Set verbose level (-v -v / -v 2)";
                $optsRef->{'verbose'} = sub {
                    my ($argument, $value) = @_;
                    if($value){
                        setLoggLevel($value);
                    }else{
                        incrementLoggLevel();
                    }
                    logg(5, "Logging increased to ".getLoggLevel());
                }
            }
            unless($commandOptsRef->{'colour|color'} || $commandOptsRef->{'colour'} || $commandOptsRef->{'color'}){
                $commandOptsRef->{'colour|color!'} = "Set logg colour output";
                $optsRef->{colour} = sub {
                    my ($argument, $value) = @_;
                    setLoggColour($value);
                };
            }
            unless($commandOptsRef->{'config-file=s'}){
                $commandOptsRef->{'config-file=s'} = "Provide a path to a config file that has the CLI opts already setup";
                $optsRef->{'config-file'} = sub {
                    my ($argument, $value) = @_;
                    if($value =~ /\.ya?ml$/){
                        open my $fh, "<", $value or die "$!";
                        my $config = Load(join("", <$fh>));
                        close $fh;
                        for my $key(keys %{$config}){
                            $optsRef->{$key} = $config->{$key};
                        }
                        my $currentOpts = $commandOptsRef;
                        my $currentConfig = $config;
                        OUTER:
                        while(1){
                            for my $key(keys %{$currentConfig}){
                                if(ref($currentOpts->{$key}) eq "HASH"){
                                    $currentOpts = $currentOpts->{$key};
                                    $currentConfig = $currentConfig->{$key};
                                    push @{$chosenCommands}, $key;
                                    next OUTER;
                                }
                            }
                            last;
                        }
                    }else{
                        loggDie("Config file extention not supported (must be a yaml file): $value");
                    }
                    $optsRef->{"config-file"} = $value;
                };
                $commandOptsRef->{'generate-config-file'} = "Dump to the screen a config file of the arguments provided";
                $optsRef->{'generate-config-file'} = sub {
                    if(@ARGV){
                        logg({STDERR=>1,fg=>"red"}, "The following options were added afterwards and will be ignored: @ARGV");
                    }
                    my $config = {};
                    for my $key(keys %{$optsRef}){
                        $config->{$key} = $optsRef->{$key} unless(ref($optsRef->{$key}) eq "CODE");
                    }
                    print Dump($config);
                    exit;
                };
            }
        }
        sub sortOptions($){
            my $optionsRef = shift;
            my %options = ();
            my %commands = ();
            my @help = ();
            my $optionExtraOpts = {};
            for my $key(keys %$optionsRef){
                my $ref = ref $optionsRef->{$key};
                if($ref eq "HASH"){
                    $commands{$key} = $optionsRef->{$key};
                }elsif($key eq '?'){
                    if($ref eq "ARRAY"){
                        if(ref($optionsRef->{$key}->[0]) eq "HASH"){
                            $optionExtraOpts = shift @{$optionsRef->{$key}};
                            push @help, @{$optionsRef->{$key}};
                            unshift @{$optionsRef->{$key}}, $optionExtraOpts;
                        }else{
                            push @help, @{$optionsRef->{$key}};
                        }
                    }else{
                        push @help, $optionsRef->{$key};
                    }
                }else{
                    $options{$key} = $optionsRef->{$key};
                }
            }
            return (\%options, \%commands, \@help, $optionExtraOpts);
        }
        sub printOptions2($$){
            my %options = %{$_[0]};
            my @help    = @{$_[1]};
            logg({fg=>'grey'}, @help, "") if(@help);
            my $OPTIONS_LENGTH = getLongest(map {join(", ", @{getOptionsAliases($_)})} keys %options);
            $OPTIONS_LENGTH += 2;
            my @common_opts = ();
            my @opts = ();
            OUTER:
            for my $k(sort keys %options){
                my $map = {};
                my $key = $k;
                my $d = "";
                $d = "$2$1"  if($k =~ s/([=:+])[si]?([\@%]?)$//);
                my @keys  = @{getOptionsAliases($key)};
                my @lines;
                if(ref $options{$key} eq "ARRAY"){
                    if(ref $options{$key}->[0] eq "HASH"){
                        $map = shift @{$options{$key}};
                    }
                    my $first_line = '';
                    $first_line .= '* ' if($map->{required});
                    if(defined $map->{default}){
                        my $defaultPrompt = $d ?
                            (ref($map->{default}) eq "ARRAY" ? join(",", @{$map->{default}}) : $map->{default})
                            :
                            ($map->{default} ? "true" : "false");
                        $first_line .= "[".$defaultPrompt."] ";
                    }
                    $first_line .= shift @{$options{$key}} || '';
                    @lines = (sprintf("%${OPTIONS_LENGTH}s %2s %s", join(", ", @keys), $d, $first_line || ''));
                    if(logg(1)){
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
                logg($_) for @common_opts;
                print "\n"
            }
            logg($_) for @opts;
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
                    if(logg(1)){
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
            my ($options, $commands, $help) = sortOptions($currentCommand);
        
            my $current_arg_key;  # The key they put on command line (e.g. -f)
            my $current_arg_opt;  # The opt name (e.g. --file|-f=s)
            my $current_arg_opts; # The opts for that opt (e.g. [{autocomplete:[aaaa,aaa]},The AWS profile to use])
            if(@ARGV and $ARGV[$#ARGV] =~ /^--?[^-]/){
                $current_arg_key = $ARGV[$#ARGV];
            }
        
            for my $opt(keys %{$options}){
                $opts{getOptionsAliases($opt)->[0]}++;
                if($current_arg_key){
                    for my $alias(@{getOptionsAliases($opt)}){
                        if($alias eq $current_arg_key){
                            $current_arg_opts = $options->{$opt};
                            $current_arg_opt = $opt;
                        }
                    }
                }
            }
        
            for my $command(@$chosenCommands){
                $currentCommand = $currentCommand->{$command};
                ($options, $commands, $help) = sortOptions($currentCommand);
                for my $opt(keys %{$options}){
                    $opts{getOptionsAliases($opt)->[0]}++;
                    if($current_arg_key){
                        for my $alias(@{getOptionsAliases($opt)}){
                            if($alias eq $current_arg_key){
                                $current_arg_opts = $options->{$opt};
                                $current_arg_opt = $opt;
                            }
                        }
                    }
                }
            }
            for my $subCommand(keys %{$commands}){
                my ($alias) = split('\|', $subCommand);
                $opts{$alias}++;
            }
        
            if($current_arg_opts and ref($current_arg_opts) eq "ARRAY" and ref($current_arg_opts->[0]) eq "HASH"){
                my $arg_opts = $current_arg_opts->[0];
                if($arg_opts->{options}){
                    print "$_\n" for @{$arg_opts->{options}};
                    exit;
                }elsif($arg_opts->{autocomplete} and ref($arg_opts->{autocomplete}) eq "ARRAY"){
                    print "$_\n" for @{$arg_opts->{autocomplete}};
                    exit;
                }elsif($arg_opts->{autocomplete} and ref($arg_opts->{autocomplete}) eq "CODE"){
                    print "$_\n" for @{$arg_opts->{autocomplete}->()};
                    exit;
                }elsif($current_arg_opt =~ /=/){
                    exit;
                }
            }
            print "$_\n" for sort keys %opts;
            exit;
        }
        sub getOptionsError {
            printHelp(shift, shift, shift);
            my $errorMessage = shift || "An error ccured while parsing options. See output for more details";
            loggDie($errorMessage);
        }
        1;
    }
    { ##### IMPORTED MODULE: BAUK::Getopt
        package BAUK::Getopt;
        use strict;
        use warnings;
        use Getopt::Long;
        BAUK::logg::simple->import();
        BAUK::definitions->import();
        BAUK::Getopt::v2->import();
        use Exporter qw(import);
        our @EXPORT    = qw(BaukGetOptions checkUserOptions BaukGetOptionsCompletion BaukGetOptions2);
        my %c = ( # c = custom
            help    => 1,
            verbose => 1,
            colour  => 1,
        );
        sub checkUserOptions($$$){ # (\%opts, \%commandOpts, |arg| or |[arg1, arg2]| or |{arg1=>"default1", arg2=>"default2"}| )
            BAUK::choices->import();
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
        sub BaukGetOptions {
            return BaukGetOptions2(@_);
        }
        sub BaukGetOptionsCompletion($){
            my $map = shift;
            my $commandOptsRef  = $map->{options} || $map->{opts} || die "Need to provide an options hash to get Completion";
            my $command = $map->{command} || die "Need to provide a command";
            my @options = @{$map->{custom} || []};
        
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
    { ##### IMPORTED MODULE: BAUK::config
        package BAUK::config;
        use strict;
        use warnings;
        BAUK::logg->import();
        BAUK::choices->import();
        use Cwd qw[abs_path];
        use Exporter qw(import);
        our @EXPORT = qw(getBaukConfig getBaukConfigValue setBaukConfigValue getBaukConfigFile setBaukConfigFile);
        my $DELIM       = "=";
        my $HASH_DELIM  = ":";
        my $CONFIG_DIR  = "$ENV{HOME}/.bauk";
        my $CONFIG_FILE = $CONFIG_DIR ? "$CONFIG_DIR/bauk.config" : abs_path("bauk.config");
        my %config = (
        );
        sub getAllBaukConfig();
        if($CONFIG_DIR and ! -d $CONFIG_DIR){
            mkdir $CONFIG_DIR or die "Could not make dir: $CONFIG_DIR: $!";
        }
        { # Temporary block to copy confg to new location in case it has already been setup
            use File::Copy;
            if($ENV{BAUK_REPO} and -f "$ENV{BAUK_REPO}/bauk.config" and ! -f $CONFIG_FILE){
                warn "Copying over config from $ENV{BAUK_REPO}/bauk.config to new location: $CONFIG_FILE\n";
                copy("$ENV{BAUK_REPO}/bauk.config", $CONFIG_FILE) or die "Could not copy over old config location: $!";
            }
        }
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
            logg(3,
                "Getting Config with BASE         : ".$area,
                "Getting Config with specific keys: ".join(" ", keys %specificConfigRaw));
            my %specificConfig = ();
            $specificConfig{"$area.$_"} = $specificConfigRaw{$_} for(keys %specificConfigRaw); # Prepend the area to the config
            getAllBaukConfig();
        
            %specificConfigRaw = ();
            for my $key (keys %specificConfig){
                my $keyEnd = $key;
                   $keyEnd =~ s/^$area\.*//;
                if(not exists $config{$key}){
                    $config{$key} = getBaukConfigValue($key, $specificConfig{$key}, 1);
                }
                $specificConfig{$key}       = $config{$key};
                $specificConfigRaw{$keyEnd} = $config{$key};
            }
            $hashRef->{$_} = $specificConfigRaw{$_} for(keys %specificConfigRaw); # Update the hashRef passed
            saveBaukConfig();
            return %specificConfigRaw;
        }
        sub getBaukConfigValue($@){
            my $key          = uc(shift);
            my $defaultValue = shift;
            my $putValue     = shift ;#|| 0;
            getAllBaukConfig();
            if((not(defined $config{$key}) and defined $defaultValue) or $putValue){
                if(ref $defaultValue eq "HASH" and $key !~ m/\%$/){
                    $config{$key} = askForConfigValue($key, $defaultValue);
                }else{
                    $config{$key} = $defaultValue;
                }
                saveBaukConfig();
            }
            return @{$config{$key}} if(ref $config{$key} eq "ARRAY");
            return %{$config{$key}} if(ref $config{$key} eq "HASH");
            return $config{$key};
        }
        sub setBaukConfigValue($$){ # $item, $value
            return getBaukConfigValue($_[0], $_[1], 1);
        }
        sub askForConfigValue($$){
            my $key     = shift;
            my %options = %{$_[0]};
               $options{show} = 1;
            my $prompt = delete($options{_prompt}) || "Choose config value for '$key' : ";
            return choice($prompt, \%options);
        }
        sub getAllBaukConfig(){
            logg(3, "GETTING BAUK CONFIG");
            my $fh;
            if(open($fh, "<$CONFIG_FILE")){
                while(<$fh>){
                    s/\s*$//; # Remove trailing spaces and new-line
                    if(/^#/){
                    }else{
                        my @row = split " *$DELIM *", $_;
                        my $key = uc $row[0];
                        my $value;
                        if(defined $row[1]){$value = $_; $value =~ s/[^$DELIM]*$DELIM *//}
                        else{ $value = $config{$key} || 0;}
        
                        logg(6, sprintf("Obtaining Config %-35s with value: %s",$key, $value));
                        if($key =~ /\@$/){
                            logg(7, sprintf("Obtaining Config %-35s with value: %s (%s)",$key, $value, ref $value));
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
    { ##### IMPORTED MODULE: BAUK::main
        package BAUK::main;
        use strict;
        use warnings;
        use Exporter qw(import);
        our @EXPORT = qw();
        BAUK::logg::simple->import();
        push @EXPORT, qw(logg loggTitle loggAppend loggWarn);
        BAUK::logg::extra->import();
        push @EXPORT, qw(loggDie loggWarn);
        BAUK::Getopt->import();
        push @EXPORT, qw(BaukGetOptions BaukGetOptions2);
        BAUK::config->import();
        push @EXPORT, qw(getBaukConfigValue getBaukConfig);
        BAUK::bauk->import();
        push @EXPORT, qw(vim);
        BAUK::shell->import();
        push @EXPORT, qw(execute executeOrDie executeOrManual);
        setLoggLevel(getBaukConfigValue("LIB.PERL.BAUK.LOGG.BASE_VERBOSE", 0));
        setLoggColour(getBaukConfigValue("LIB.PERL.BAUK.LOGG.BASE_COLOUR", 1));
        1;
    }
    { ##### IMPORTED MODULE: BAUK::logg::commands
        package BAUK::logg::commands;
        use strict;
        use warnings;
        BAUK::logg::simple->import();
        BAUK::logg::extra->import();
        BAUK::threads->import();
        BAUK::shell->import();
        use Exporter qw(import);
        our @EXPORT = qw(loggExec);
        sub loggExec($){
            my $in = shift;
            my $command = delete($in->{command}) || delete($in->{c}) || die "Need to provide a command to Execute";
            my $level   = (defined $in->{level})  ? delete($in->{level})  : 2;
            my $die     = (defined $in->{die})    ? delete($in->{die})    : 1;
            my $status  = (defined $in->{status}) ? delete($in->{status}) : 1;
            my $logs    = (defined $in->{logs})   ? delete($in->{logs})   : 0; # Whether to return just logs
            my $wrap    = (defined $in->{wrap})   ? delete($in->{wrap})   : 1;
        
            my $sub;
            if(ref($command) eq 'CODE'){
                if($wrap){
                    $sub = sub {
                        my %ret = (
                            exit => 0,
                            log => [],
                            data => undef,
                        );
                        eval {
                            $ret{data} = $command->();
                        }; if($@){
                            $ret{log} = [$@];
                            $ret{exit} = 1;
                        }
                        return \%ret;
                    };
                }else{
                    $sub = $command;
                }
            }else{
                if($command !~ /^ *[a-z]{0,2}sh /){ # Don't wrap in bash if it is already a bash/sh/ksh/zsh command
                    $command =~ s#'#'"'"'#g;
                    $command = "bash -c '$command'";
                }
                $command .= " 2>&1";
                $command .= " | tee /dev/tty && exit \${PIPESTATUS[0]}" if(logg($level));
                $sub = sub {return execute($command)};
            }
            my $return;
            if(logg($level)){
                logg(0, "loggExec: $in->{logg}") if($in->{logg});
                $return = \$sub->();
            }else{
                my %loaderOpts = (
                    spinner => "cradle",
                    %{$in},
                    sub     => $sub
                );
                if($status){
                    $loaderOpts{newline} = 0;
                }
                $return = threadLoader(\%loaderOpts);
            }
            $return = $$return if(ref($return) eq "REF");
            if(ref($return) ne "HASH"){
                loggWarn("Cannot show status or die as return from loggExec is not a hash (".ref($return).")") if($die || $status);
                return $return;
            }
            my %status = %{$return};
            if($status{exit} and $die){
                loggDie("FAILED",
                    "COMMAND: $command",
                    "EXIT   : $status{exit}",
                    "LOG    : ", @{$status{log}}
                );
            }elsif($status){
                if(not defined ($status{exit})){
                    loggWarn("Cannot obtain status from command as exit not returned");
                }if($status{exit}){
                    loggAppend({fg=>"red"}, "FAILED");
                }else{
                    loggAppend({fg=>"green"}, "SUCCESS");
                }
            }
            return @{$status{log}} if $logs;
            return $status{data} if(defined($status{data}));
            return %status;
        }
        1;
    }
} # MODULES END
use strict;
use warnings;
BAUK::choices->import();
BAUK::main->import();
BAUK::files->import();
BAUK::JsonFile->import();
BAUK::logg::buffer->import();
BAUK::logg::commands->import();
BAUK::errors->import();
use Cwd qw[abs_path];
use JSON;
# # # # # # #  CONFIG
my %commandOpts     = (
# --verbose and --help from BAUK::main->BaukGetOptions()
    'update|u'                  => "To update tags",
    'build|b'                   => "To build the image first to ensure it works",
    'push'                      => [{onlyif=>"build"}, "To push the images to dockerhub too (If automated builds are not setup)"],
    'group|g'                   => "Group mode, to push tags in groups for speed",
    'max|m=i'                   => "Max tags to update",
    'dir|d=s@'                  => "Dir to update",
    'sockets|s'                 => "To use ssh sockets to speed up pushes",
    'reverse|r'                 => "To reverse tag order and do newest first",
    'update-unbuilt|U'          => "To update any tags that have not been built",
    'minus-pending-from-max|M'  => "Minus any pending builds on dockerhub from the max. Requires a valid token.",
    'show-builds'               => "Standalone option that just lists the state of current builds on dockerhub",
);
my %VERSION_SPECIFIC_ARGS = (
    # WARNING: Used sed## so cannot contain hash/#
    CENTOS_BUILD_BASE => {
        '0.0.0'     => 'bauk/git:centos7-build-base',
        '2.8.3'     => 'bauk/git:centos8-build-base',
    },
    FEDORA_BUILD_BASE => {
        '0.0.0'     => 'bauk/git:fedora39-build-base',
    },
);
my $DEFAULT_OS = "fedora";
my $JSON = JSON->new()->pretty();
my $SCRIPT_DIR = abs_path(__FILE__ . "/..");
my $CACHE = BAUK::JsonFile->new({
  file=>"$SCRIPT_DIR/.setupTags.docker-tag-cache.json",
  ignoreMissing=>1,
})->load();
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
# Testing: compareVersions
#my @v = qw[
#    1.1.1 1.2.3
#    10.4.5 9.0.0
#    0.10.0 0.9.0
#    0.0.10 0.0.9
#    0.0.10 0.0.90
#    1.2.33 1.2.33
#];
#while(@v){
#    my $a = shift @v;
#    my $b = shift @v;
#    logg(0, "$a <> $b = ".compareVersions($a, $b));
#    logg(0, "$b <> $a = ".compareVersions($b, $a));
#}
#exit;
if($opts{"show-builds"}){
    getDockerhubBuildStatuses();
    exit;
}
prepareRepo();
logg({format=>0}, "Downloading versions...");
# TODO Do all curls in parallel as it saves time
my $page = 0;
my @git_versions = @{executeOrDie('curl -sS https://mirrors.edge.kernel.org/pub/software/scm/git/|sed -n "s#.*git-\([0-9\.]\+\).tar.gz.*#\1#p"|sort -V')->{log}};
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
sub compareVersions {
    # Very simple implementation. Does not cater for things like 1.2.3-asas vs 1.2.10
    my $a = shift;
    my $b = shift;
    return 0 if($a eq $b);
    my @a = split('\.', $a);
    my @b = split('\.', $b);
    while(@a){
        my $aa = shift @a;
        my $bb = shift @b;
        if($aa eq $bb){
            next;
        }elsif($aa =~ /^[0-9]+$/ and $bb =~ /^[0-9]+$/){
            return $aa <=> $bb;
        }else{
            return $aa cmp $bb;
        }
    }
    return 0;
}
sub prepDockerfiles {
    my $in = shift;
    my $version = $in->{version} || die "TECHNICAL ERROR";
    my $dir = $in->{dir} || die "TECHNICAL ERROR";
    executeOrDie("sed -i 's/ARG VERSION=.*/ARG VERSION=$version/' $dir/Dockerfile-*");
    for my $arg(keys %VERSION_SPECIFIC_ARGS){
        my $value;
        for my $ver(sort { compareVersions($a, $b) } keys %{$VERSION_SPECIFIC_ARGS{$arg}}){
            if(compareVersions($version, $ver) >= 0){
                $value = $VERSION_SPECIFIC_ARGS{$arg}->{$ver};
            }
        }
        executeOrDie("sed -i 's#{{$arg}}#$value#' $dir/Dockerfile-*");
    }
}
sub doVersion {
    my $in = shift;
    # loggBufferAppend("DOING VERSION");
    loggBufferSave();
    my $version = $in->{version} || die "TECHNICAL ERROR";
    my $version_tag = $in->{version_tag} || die "TECHNICAL ERROR";
    my $dir = $in->{dir} || die "TECHNICAL ERROR";

    if(!$opts{build}){
        logg(0, "Not building as --build not specified. Assuming will work.");
        updateTag($in);
        return;
    }
    prepDockerfiles($in);
    if($opts{push}){
        buildVersion($in);
    }else{
        if($in->{last_working_minor} and $version =~ /^$in->{last_working_minor}/){
            logg(0, "Assuming it will work as minor worked: $in->{last_working_minor}");
        }elsif($in->{last_broken_minor} and $version =~ /^$in->{last_broken_minor}/){
            logg(0, "Assuming it will NOT work as minor did not: $in->{last_broken_minor}");
        }else{
            buildVersion($in);
        }
    }
    updateTag($in);
}
sub buildVersion {
    my $in = shift;
    my $version = $in->{version} || die "TECHNICAL ERROR";
    my $version_tag = $in->{version_tag} || die "TECHNICAL ERROR";
    my $dir = $in->{dir} || die "TECHNICAL ERROR";

    for my $dockerfile(glob "$dir/Dockerfile-*"){
        $dockerfile =~ s|$dir/||;
        my $tag = $dockerfile;
        $tag =~ s/Dockerfile-//;
        $tag .= "-$dir" unless($dir eq "app");
        $tag .= "-$version";
        logg(0, "Doing version: $version ($dockerfile)");
        my %exec = %{execute("cd $dir && docker build . --file $dockerfile --tag git_tmp")};
        if($exec{exit} != 0){
            logg(0, "Buid failed");
            $in->{last_broken_minor} = $version;
            $in->{last_broken_minor} =~ s/^([^0-9]*\.[^0-9]*).*/$1/;
            return;
        }
        my @log = @{executeOrDie("docker run --rm -it --entrypoint git git_tmp --version")->{log}};
        unless(grep $version, @log){
            logg(0, "Buid corrupt somehow");
            $in->{last_broken_minor} = $version;
            $in->{last_broken_minor} =~ s/^([^0-9]*\.[^0-9]*).*/$1/;
            return 1;
        }
        logg(0, "Build success");
        if($opts{push}){
            logg(0, "Pushing image tag $tag...");
            executeOrDie("docker tag git_tmp bauk/git:$tag");
            executeOrDie("docker push bauk/git:$tag");
            if(-f "$dir/hooks/post_push"){
                $ENV{DOCKERFILE_PATH} = "$dockerfile";
                $ENV{SOURCE_BRANCH} = $version_tag;
                $ENV{DOCKER_TAG} = "$tag";
                $ENV{DOCKER_REPO} = "bauk/git";
                $ENV{IMAGE_NAME} = "bauk/git:$tag";
                # To debug the post_hook script
                #print "export DOCKERFILE_PATH=$dockerfile\n";
                #print "export SOURCE_BRANCH=$version\n";
                #print "export DOCKER_TAG=$tag\n";
                #print "export DOCKER_REPO=bauk/git\n";
                #print "export IMAGE_NAME=bauk/git:$tag\n";
                #exit;
                logg(0, @{executeOrDie("$dir/hooks/post_push")->{log}});
            }
        }
    }
    logg(0, "All builds successfull");
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
                    $docker_tag = "${DEFAULT_OS}-${version}-${parent_commit}";
                }elsif($dir eq "build"){
                    # Builds do not care about the parent commit, they are just compilation images
                    $docker_tag = "${DEFAULT_OS}-$dir-${version}";
                }else{
                    $docker_tag = "${DEFAULT_OS}-$dir-${version}-${parent_commit}";
                }
                if($opts{"update-unbuilt"}
                  && ! (dockerTagExists($docker_tag)
                     || (grep /^${DEFAULT_OS}-${version}$/, @CURRENT_BUILDS) # As builds in progress will not have the full docker tag with ID
                  )){
                    loggBufferAppend("RETAGGING TO REBUILD");
                    doVersion({%{$in}, version => $version, version_tag => $version_tag});
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
                doVersion({%{$in}, version => $version, version_tag => $version_tag});
            }else{
                loggBufferAppend("SKIPPING - pass -u flag to update");
            }
        }else{
            logg(0, "New version: $version_tag");
            doVersion({%{$in}, version => $version, version_tag => $version_tag});
        }
    }
    loggBufferEnd();
}
sub dockerTagExists {
  my $tag = shift;
  if($CACHE->get($tag)){
    return 1;
  }
  if(execute("curl --silent -f -lSL 'https://hub.docker.com/v2/namespaces/bauk/repositories/git/tags/$tag' 2>&1")->{exit} == 0){
    $CACHE->set($tag, 1);
    $CACHE->save();
    return 1;
  }
  return 0;
}
sub updateTag {
    my $in = shift;
    my $version = $in->{version};
    my $dir = $in->{dir};
    my $tag_prefix = $dir eq "app" ? "" : "$dir/";
    executeOrDie("git reset origin/master");
    prepDockerfiles($in);
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
        ." -H 'Authorization: Bearer $token'"});
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

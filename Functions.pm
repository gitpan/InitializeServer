;############################################################
;# 
;# Examples: 
;# 
;# A Server started from inetd (or a mail alias/filter):
;#     use Server::Initialize::Functions qw(startAsPipe);
;#     startAsPipe('MY_SERVER','MY_DIR','LOGFILE');
;#     &process_request_from_STDIN;
;#     exit;
;# 
;# A Server started not from inetd, which should only have one copy running:
;#     use Server::Initialize::Functions qw(startUnique);
;#     startUnique('MY_SERVER','MY_DIR','LOCK','LOGFILE');
;#     &start_server_socket
;#     &loop_process_requests_from_socket
;# 

package Server::Initialize::Functions;
use Usage;
use Carp qw(croak);
require AutoLoader;
require Exporter;
use Ioctl qw(TIOCNOTTY);
use Wait qw(WNOHANG);

#Null DESTROY, to handle AutoLoader bug
DESTROY {}


@ISA = qw(AutoLoader Exporter);
@EXPORT = ();
@EXPORT_OK = qw(setLogFile startUnique startAsPipe background
		setNameMaskDirGrp handleSignals setLockFile pidAlive
		nameAlive detachFromTty resetOpenDescriptors
		setChldSignalHandler);

%USAGE_ALIAS = (
'SERVER_DIRECTORY' => 
  ['FILETEST(d)',
   'The directory to use as home for the server'
  ],
'LOCK_FILE' => 
  ['FILETEST(rw,>)',
   'The lock file for the Server'
  ],
'SERVER_NAME' => 
  ['ANYTHING',
   'The name of this Server for the system table'
  ],
'ERROR_OUTPUT' => 
  ['ONE_OF(STDERR,CONSOLE,LOGFILE,DEVNULL)',
   'Where STDERR is redirected to - STDERR/CONSOLE/LOGFILE/DEVNULL'
  ],
'BOOLEAN' => 
  ['ANYTHING',
   'False to close STDIN/STDOUT, or true leave them open'
  ],
);

$PS = (-e '/vmunix') ? '/bin/ps -axww' : '/bin/ps -ef';
;#$LOGFILE;	# Set this, using 'setLogFile' - defaults to servername.log
$TIMED_OUT = 'TIMED_OUT';

sub setLogFile {
    setUsage('FILETEST(w,>)');
    &checkUsage;

    # Takes one argument - the path to a writeable file
    # which will be the logfile. Should be an absolute path
    # name (beginning with '/').
    # Used by 'resetOpenDescriptors' if STDERR is specified to go
    # to a logfile.

    $LOGFILE = $_[0];
}

sub startUnique {
    setUsage('SERVER_NAME','SERVER_DIRECTORY','LOCK_FILE','ERROR_OUTPUT');
    &checkUsage;

    # 'startUnique' is intended to be called by a daemon running
    # permanently in background.

    # Takes four arguments:
    #  the name for the server (sets $0);
    #  the directory to use as home (chdir's to it);
    #  the path to the server lock file (keeps the pid in it)
    #  the location for error output to go - see 'resetOpenDescriptors'

    # 'startUnique' puts the process into the background, sets
    # the name, directory, umask and process group, redirects STDERR
    # STDOUT and STDIN, and detaches from the controlling terminal.
    # It also sets the lockfile - unless another running process is
    # listed in the lock file, in which case 'startUnique' will exit
    # (i.e enforces only one server using the lockfile running at a time).

    # STDIN/STDOUT are closed. If you redirect STDERR to /dev/null,
    # then you probably want to use syslog.  At the moment
    # you're on your own about this - though when I'm happier
    # with Syslog, the way I'll do it is probably to catch warn's and
    # die's with $SIG{__WARN__} and $SIG{__DIE__}, and redirect them
    # to syslog. Trouble is, this won;t catch a 'print STDERR'. Hmm -
    # any suggestions?

    my($name,$dir,$lock_file,$eo) = @_;
    background();
    setNameMaskDirGrp($name,$dir);
    handleSignals();
    setLockFile($lock_file,$name);
    detachFromTty();
    resetOpenDescriptors($eo,0);
}

sub startAsPipe {
    setUsage('SERVER_NAME','SERVER_DIRECTORY','ERROR_OUTPUT');
    &checkUsage;

    # 'startAsPipe' is intended to be called by a process which
    # is started as a pipe, for example an inetd service or a mail
    # filter called from /etc/aliases.

    # Takes three arguments:
    #  the name for the server (sets $0);
    #  the directory to use as home (chdir's to it);
    #  the location for error output to go - see 'resetOpenDescriptors'

    # 'startAsPipe' puts the process into the background, sets
    # the name, directory, umask and process group, redirects STDERR
    # STDOUT and STDIN, and detaches from the controlling terminal.

    # STDIN/STDOUT are NOT closed. If you redirect STDERR to /dev/null,
    # then you probably want to use syslog. At the moment
    # you're on your own about this - though when I'm happier
    # with Syslog, the way I'll do it is probably to catch warn's and
    # die's with $SIG{__WARN__} and $SIG{__DIE__}, and redirect them
    # to syslog. Trouble is, this won;t catch a 'print STDERR'. Hmm -
    # any suggestions?

    my($name,$dir,$eo) = @_;
    setNameMaskDirGrp($name,$dir);
    handleSignals();
    resetOpenDescriptors($eo,1);
}

sub background {
    setUsage(); &checkUsage;

    # Takes no arguments. Puts the current process in the background.

    my($pid,$i);
    for ($i=0;$i <= 20;$i++) {
	defined($pid = fork) && last;
    }
    if (defined($pid)) {
	$pid && exit;
    } else {
	croak("Fatal error: Unable to fork the process: $!");
    }
}

sub setNameMaskDirGrp {
    setUsage('SERVER_NAME','SERVER_DIRECTORY'); &checkUsage;

    # Takes two arguments:
    #  the name for the process (sets $0);
    #  the directory to use as home (chdir's to it);
    # In addition, the umask is set to '027', and the process
    # group set to the process number.

    # WARNING. When you change directory, any further 'require's
    # and 'use's no longer see '.' as the directory at which you started.
    # '.' is now the new directory. I know this seems obvious, but
    # you can sometimes start a script in your test 'lib' directory
    # rather than make the effort of writing out the path for -I
    # or explicitly doing a push(@INC,...), and this chdir will
    # take you out of the directory so you could then start getting
    # 'can't find such and such module' errors and not immediately
    # see why.

    my($name,$dir) = @_;
    $0 = $name;
    chdir($dir) || croak("Fatal error: Unable to change to '$dir'");
    umask(027);
    setpgrp(0,$$);
}

sub handleSignals {
    # Null. I'll get to it when I decide if there are any generic
    # signals that should automatically be handled by a server
    # by default. But see 'setChldSignalHandler' in this module.
}


sub setLockFile {
    setUsage('LOCK_FILE','SERVER_NAME'); &checkUsage;

    # Takes two arguments:
    #  the path for the lock file;
    #  and the name for the process (sets $0);
    # Checks to see if the process listed in the lockfile is running,
    # and if not, writes its own pid to the file. Otherwise exits.

    my($lock_file,$name) = @_;
    my($proc,$ctime,$ctime2,@pids);
    if (-e $lock_file) {
	$ctime = (stat($lock_file))[10];
	
	while ($ctime != $ctime2) {
	    $ctime2 = $ctime;
	    open(Server::Initialize::Functions::LOCK,"$lock_file") ||
		croak("Fatal error: Couldn't read lock file '$lock_file': $!");
	    $proc = <Server::Initialize::Functions::LOCK>;
	    close Server::Initialize::Functions::LOCK;
	    if (pidAlive($proc)) {
		print STDERR "Server '$name' is already running, not starting another\n";
		exit;
	    }
	    $ctime = (stat($lock_file))[10];
	}
    }

    open(Server::Initialize::Functions::LOCK,">$lock_file") ||
	croak("Fatal error: Couldn't write to lock file '$lock_file': $!");
    print Server::Initialize::Functions::LOCK $$;
    close Server::Initialize::Functions::LOCK;

    if ((@pids = nameAlive($name))) {
	print STDERR "Warning: detected processes with Server name '$name' in them: PIDS: @pids\n";
    }

}

sub pidAlive {
    setUsage('INTEGER(>,-1)'); &checkUsage;
    my($pid) = @_;

    # Takes one argument: a process id.
    # Tries to check whether the pid is running (returns true) or
    # not (returns false).

    my($u,$p,$rest,$bool,$title);
    open(Server::Initialize::Functions::PS,"$PS |") ||
	croak("Fatal error: unable to execute /bin/ps: $!");
    $title = <Server::Initialize::Functions::PS>;     # Throwaway the title
    while(<Server::Initialize::Functions::PS>) {
	($u,$p,$rest) = ($_ =~ /^\s*(\S*)\s+(\d+)\s+(.*)$/);
	$p == $pid && ($bool = 1) && last;
    }
    close Server::Initialize::Functions::PS;
    $bool;
}

sub nameAlive {
    setUsage('SERVER_NAME'); &checkUsage;
    my($name) = @_;

    # Takes one argument: a process name.
    # returns a list of pids which include that name.

    my($u,$p,$rest,$title,@pids);
    open(Server::Initialize::Functions::PS,"$PS |") ||
	croak("Fatal error: unable to execute /bin/ps: $!");
    $title = <Server::Initialize::Functions::PS>;     # Throwaway the title
    while(<Server::Initialize::Functions::PS>) {
	($u,$p,$rest) = ($_ =~ /^\s*(\S*)\s+(\d+)\s+(.*)$/);
	$p == $$ && next;
	$name && ($rest =~ /$name/) && push(@pids,$p);
    }
    close Server::Initialize::Functions::PS;
    @pids;
}

sub detachFromTty {
    setUsage(); &checkUsage;

    # Detaches the process from the controlling tty.

    open(Server::Initialize::Functions::TTY,"+>/dev/tty") ||
	croak("Fatal error: Couldn't detach from controlling tty: $!");
    ioctl(Server::Initialize::Functions::TTY,TIOCNOTTY,"\0" x 300);
    close(Server::Initialize::Functions::TTY);
}

sub resetOpenDescriptors {
    setUsage('ERROR_OUTPUT','BOOLEAN'); &checkUsage;
    # I assume they are just STDIN/STDOUT/STDERR
    my($eo,$bool) = @_;

    # Takes two args:
    #  the location for error output to go - see below;
    #  and a boolean which should be false to redirect STDIN/STDOUT to
    #  /dev/null (as you should probably do for a daemon), or true to 
    # leave them open (as you need for a piped server).

    #  The location for error output to go -  this is one of
    #    STDERR/CONSOLE/LOGFILE/DEVNULL, where
    #    STDERR leaves STDERR alone,
    #    CONSOLE redirects STDERR to /dev/console
    #    DEVNULL basically closes STDERR
    #    LOGFILE redirects STDERR to the logfile (set with 'setLogFile')
    #        which defaults to the server name ($0) appended with '.log'

    # If you want to log messages to SYSLOG then use DEVNULL and handle
    # logging yourself. At the moment you're on your own about this -
    # though when I'm happier with Syslog, (in a future version)
    # the way I'll do it is probably to catch warn's and
    # die's with $SIG{__WARN__} and $SIG{__DIE__}, and redirect them
    # to syslog. Trouble is, this won;t catch a 'print STDERR'. Hmm -
    # any suggestions? There will probably be a SYSLOG output location
    # option then.

    # Don't close things if we have pending data
    if (!$bool) {
	close(STDIN);
	open(STDIN,"</dev/null") || croak("Fatal error: open STDIN: $!");

	close(STDOUT);
	open(STDOUT,">/dev/null") || croak("Fatal error: open STDOUT: $!");
    }

    if      ($eo eq 'STDERR') {
	# Do nothing, just leave STDERR open as normal
    } elsif ($eo eq 'LOGFILE') {
	close(STDERR);
	if ($LOGFILE) {
	    open(STDERR,">$LOGFILE") || die;
	} else {
	    open(STDERR,">$0.log") || die;
	}
    } elsif ($eo eq 'CONSOLE') {
	close(STDERR);
	open(STDERR,">/dev/console") || die;
    } elsif ($eo eq 'DEVNULL') {
	close(STDERR);
	open(STDERR,">/dev/null") || die;
    }
}

sub setChldSignalHandler {
    setUsage('INSTANCE(CODE)'); &checkUsage;
    my($sub) = @_;

    # This subroutine sets a handler (Server::Functions::_chldSignalHandler)
    # which will catch all the SIGCHLD signals, check for any pending
    # child - exit codes (without blocking) and for any found, will
    # execute the above argument code reference with the pid of the
    # child as argument.

    # Takes one arg: a code reference which will get called
    # when a child dies and signals the parent that it has died.
    # This code referenced subroutine is passed one
    # argument - the process id for the child that has died.

    $SIG{'CHLD'} = 'Server::Initialize::Functions::_chldSignalHandler';
    $SIGCHLDSUB = $sub;
}

sub _chldSignalHandler {

    # When a child dies, you need to 'wait' for its exit code
    # or its a zombie. 
    # Pick it up

    my($pid);
    while (1) {
	$pid = waitpid(-1,WNOHANG);
	last if ($pid < 1);
	&{$SIGCHLDSUB}($pid);
    }
}

1;
__END__

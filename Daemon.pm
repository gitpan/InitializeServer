package Server::Initialize::Daemon;

# Module to initialize a daemon process. This type of process
# is usually started at the command line, or from a script

# Use as:
# 	require Server::Initialize::Daemon;
#       Server::Initialize::Daemon->initialize(CONFIG)
# where CONFIG is an object which will be asked about configuration
# parameters using the method 'CONFIG->value(KEYWORD)

# The KEYWORD's required to have values are:
#   NAME - the name for the server process
#   HOME_DIR - the directory to use as the process's home
#   LOCK_FILE - The path to the file to hold the process id
#   LOG_OUTPUT - Where to send STDERR (see Server::Initialize::Functions)

BEGIN {
    # A daemon should get into the background immediately
    # so go for an immediate fork.
    my $pid = fork();
    if (!defined($pid)) {
	die "Unable to fork: $!";
    } elsif ($pid) {
	# parent
	exit;
    }
}

use Server::Initialize::Functions qw(setNameMaskDirGrp
	handleSignals setLockFile detachFromTty resetOpenDescriptors);

sub initialize {
    my($self,$config) = @_;

    # Starts the server 'uniquely'

    # Assumes '$config' is an object which understands the method 'value'
    # and returns appropriate values for parameters:
    #   NAME - the name for the server process
    #   HOME_DIR - the directory to use as the process's home
    #   LOCK_FILE - The path to the file to hold the process id
    #   LOG_OUTPUT - Where to send STDERR (see Server::Initialize::Functions)

    setNameMaskDirGrp($config->value('NAME'),$config->value('HOME_DIR'));
    handleSignals();
    setLockFile($config->value('LOCK_FILE'),$config->value('NAME'));
    detachFromTty();
    resetOpenDescriptors($config->value('LOG_OUTPUT'),0);
}

1;
__END__

package Server::Initialize::InetdService;
use Server::Initialize::Functions qw(startAsPipe);

# Module to initialize a process being started as an Inetd service.
# This is basically the same as Server::Initialize::Pipe, but
# in addition renames the passed filehandle to whatever you
# prefer, and then resets STDIN and STDOUT to /dev/null

# Use as:
# 	require Server::Initialize::InetdService;
#       Server::Initialize::InetdService->initialize(CONFIG)
# where CONFIG is an object which will be asked about configuration
# parameters using the method 'CONFIG->value(KEYWORD)

# The KEYWORD's required to have values are:
#   NAME - the name for the server process
#   HOME_DIR - the directory to use as the process's home
#   LOG_OUTPUT - Where to send STDERR (see Server::Initialize::Functions)
#   SERVER_SOCKETNAME - The fully qualified package name to reset the
#				socket passed by inetd to.


sub initialize {
    my($self,$config) = @_;

    # Only different from Server::Initialize::Pipe in that
    # the socket handle passed from inetd is renamed
    # and then STDIN/STDOUT are closed

    # Assumes '$config' is an object which understands the method 'value'
    # and returns appropriate values for parameters:
    #   NAME - the name for the server process
    #   HOME_DIR - the directory to use as the process's home
    #   LOG_OUTPUT - Where to send STDERR (see Server::Initialize::Functions)
    #   SERVER_SOCKETNAME - The fully qualified package name to reset the
    #				socket passed by inetd to.

    startAsPipe( $config->value('NAME') ,
	$config->value('HOME_DIR') , $config->value('LOG_OUTPUT') );

    my $name = $config->value('SERVER_SOCKETNAME');

    open($name,'<&' . fileno(STDIN)) ||
	die "Couldn't duplicate the server handle: $!";

    close(STDIN);
    open(STDIN,"</dev/null") || croak("Fatal error: open STDIN: $!");

    close(STDOUT);
    open(STDOUT,">/dev/null") || croak("Fatal error: open STDOUT: $!");
}

1;
__END__

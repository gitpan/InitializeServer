package Server::Initialize::Pipe;
use Server::Initialize::Functions qw(startAsPipe);

# Module to initialize a process being piped to. This type of
# server process is usually started by some other process such
# as a mail agent program started by sendmail and listed in
# /etc/aliases as 
# name: "|/path/to/program"
# A Tcp nowait server is very similar, and this can be
# used for that. However it is probably better to use
# Server::Initialize::InetdService.

# Use as:
# 	require Server::Initialize::Pipe;
#       Server::Initialize::Pipe->initialize(CONFIG)
# where CONFIG is an object which will be asked about configuration
# parameters using the method 'CONFIG->value(KEYWORD)

# The KEYWORD's required to have values are:
#   NAME - the name for the server process
#   HOME_DIR - the directory to use as the process's home
#   LOG_OUTPUT - Where to send STDERR (see Server::Initialize::Functions)

sub initialize {
    my($self,$config) = @_;

    # Assumes '$config' is an object which understands the method 'value'
    # and returns appropriate values for parameters:
    #   NAME - the name for the server process
    #   HOME_DIR - the directory to use as the process's home
    #   LOG_OUTPUT - Where to send STDERR (see Server::Initialize::Functions)

    startAsPipe( $config->value('NAME') ,
	$config->value('HOME_DIR') , $config->value('LOG_OUTPUT') );
}

1;
__END__

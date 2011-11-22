#!/usr/bin/perl
use strict;
use warnings;
use Switch;
#use Socket;

use POE qw(Component::IRC::State);

my $irc = POE::Component::IRC->spawn(
    nick     => 'Fi',
    ircname  => 'Fi, at your service',
    username => 'Fi',
    server   => 'irc.ext3.net',
    port     => '6667',
    
) or die "Oh noooo! $!";

POE::Session->create(
    package_states => [
    main => [ qw(_default _start irc_001 irc_public irc_ctcp_action) ],
    ],
    heap => { irc => $irc },
);

$poe_kernel->run();

sub _start {
    my $heap = $_[HEAP];

    # retrieve our component's object from the heap where we stashed it
    my $irc = $heap->{irc};

    $irc->yield( register => 'all' );
    $irc->yield( connect => { } );
    return;
}

sub irc_001 {
    my $sender = $_[SENDER];

    # Since this is an irc_* event, we can get the component's object by
    # accessing the heap of the sender. Then we register and connect to the
    # specified server.
    my $irc = $sender->get_heap();

    print "Connected to ", $irc->server_name(), "\n";

    # we join our channels
    doJoin( '#fi,#ext3' );
    return;
}

sub irc_public {
    my ($sender, $who, $channel, $message) = @_[SENDER, ARG0 .. ARG2];
    my ($nick, $address) = ( split /!/, $who );
    $channel = $channel->[0]; # Get rid of the array ref

    my @what = split( /\s/, $message );
    my $command = ( shift(@what) );

    if( substr( $command, 0, 1 ) eq '.' ) {
        $command = lc( substr( $command, 1, length( $command ) - 1 ) );
        switch ( $command ) {
            case "dns" { next }
            case "host" { command_host( $nick, $channel, $what[0] ) }
            case "eval" { command_eval( $nick, $channel, join( ' ', @what ) ) }
        }
    }

    return;
}

sub irc_ctcp_action {
    my ($who, $target, $action) = @_[ARG0 .. ARG2];
    my ($nick, $address) = ( split /!/, $who );

    if( $action =~ /slaps (\w+) .*with (a|some) (\w+ )?(\w+)/ ) {
        my ($victim, $adjective, $noun) = ($1, $3, $4);
        my $myNoun = int( rand(10) );
        switch ( $myNoun ) {
            case 0 { $myNoun = 'an episode of Lost' }
            case 1 { $myNoun = 'the river' }
            case 2 { $myNoun = 'the street' }
            case 3 { $myNoun = 'a brothel' }
            case 4 { $myNoun = 'SnoFox\'s mom' }
            case 5 { $myNoun = 'the sewer' }
            case 6 { $myNoun = 'Nikki\'s food bowl' }
            case 7 { $myNoun = 'a firey fire' }
            case 8 { $myNoun = 'the path of a flaming Volkswagon' }
            case 9 { $myNoun = 'a taco' }
            case 10 { $myNoun = 'Super Mario World' }
        }
        doAction( $target, "saves $victim by catching the $noun and throwing it into $myNoun." );
    }
    return;
}

# We registered for all events, this will produce some debug info.
sub _default {
    my ($event, $args) = @_[ARG0 .. $#_];
    my @output = ( "$event: " );
    return; # I don't need the spam atm

    for my $arg (@$args) {
        if ( ref $arg eq 'ARRAY' ) {
            push( @output, '[' . join(', ', @$arg ) . ']' );
        }
        else {
            push ( @output, "'$arg'" );
        }
    }
    print join "\t", @output, "\n";
    return;
}

sub doJoin {
    my ($channel, $key) = @_;
    $irc->yield( 'join', $channel, $key );
}

sub doMsg {
    my ($target, $what) = @_;
    if( !defined($what) ) {
        $what = '[I AM ERROR]';
    }
    $irc->yield( 'privmsg', $target, $what );
}

sub doAction { my ($target, $action) = @_;
    if( !defined($action) ) {
        $action = '[I AM ERROR]';
    }
    $irc->yield( ctcp => $target => "ACTION $action" );
}

sub doDebug {
    print 'DEBUG: ' . $_[0] . "\n";
}

sub command_host {
    my ($nick, $chan, $arg) = @_;

    # if( $arg =~ // ) {
    #    command_rdns($nick, $chan, $arg);
    #    return;
    #}

    my $ip = gethostbyname($arg);

    if( defined( $ip ) ) {
        use Socket;
        doMsg( $chan, "Master $nick, I have resolved $arg to " . inet_ntoa($ip) );
    } else {
        doMsg( $chan, "Master $nick, I cannot resolve $arg. Perhaps it does not exist?" );
    }
}

sub command_eval {
    my ($nick, $chan, $args) = @_;

    if( lc( $nick ) eq 'snofox' ) {
        my $output = eval( $args );
        if( !defined( $output ) ) {
            $output = '[undef]';
        }
        doMsg( $chan, 'Perl output: ' . $output );
    } else {
        doMsg( $chan, "I apologize, $nick. However, I am directed not to issue the EVAL command for any use aside from Master SnoFox." );
    }
}

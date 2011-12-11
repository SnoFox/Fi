#!/usr/bin/perl

# This file is part of Fi. Licensing information can be found in the LICENSE file.
# If the LICENSE file is missing, visit http://github.com/SnoFox/Fi/blob/master/LICENSE for a copy.

use strict;
use warnings;
use feature qw(:5.10);
use POSIX qw(strftime);

use POE qw(Component::IRC::State);

our $version = `git log -1 --pretty=oneline|cut -d' ' -f1 2>/dev/null`;
our $DEVELOPMENT = false;

my $irc = POE::Component::IRC->spawn(
    nick     => 'Fi',
    ircname  => 'Fi, at your service',
    username => 'Fi',
    server   => 'irc.ext3.net',
    port     => '6667',
    raw      => 0
    
) or die "Oh noooo! $!";

POE::Session->create(
    package_states => [
    main => [ qw(_default _start irc_001 irc_public irc_ctcp_action irc_raw irc_raw_out) ],
    ],
    heap => { irc => $irc },
);

$poe_kernel->run();

sub _start {
    my $heap = $_[HEAP];

    # retrieve our component's object from the heap where we stashed it
    my $irc = $heap->{irc};

    doLog( '> Bot starting...!', 'info' );

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

    doLog('> Connected to ' .  $irc->server_name(), 'info' );

    # we join our channels
    doJoin( '#fi' );
    return;
}

sub irc_public {
    my ($sender, $who, $channel, $message) = @_[SENDER, ARG0 .. ARG2];
    my ($nick, $address) = ( split /!/, $who );
    $channel = $channel->[0]; # Get rid of the array ref

    my @what = split( /\s/, $message );
    my $command = ( shift( @what ) );

    doLog( "<$nick/$channel> $message", 'irc' );

    if( substr( $command, 0, 1 ) eq '.' ) {
        $command = lc( substr( $command, 1, length( $command ) - 1 ) );
    }

    my $realNick = lc($sender->[0]->{RealNick});

    if( lc( $command ) =~ /(fi|$realNick)[:,;!]/ ) {
        $command = ( shift( @what ) );
    }

    if( lc( $message ) =~ /^(badger(,| )?){12}$/ ) {
        doMsg( $channel, 'mushroom mushroom' );
    }

    parse_command( $nick, $command, $channel, @what );

    return;
}

sub parse_command {
    my ( $nick, $cmd, $target, @what ) = @_;

    given ( lc( $cmd ) ) {
        when ("dns") { continue; }
        when ("host") { command_host( $nick, $target, $what[0] ); }
        when ("rdns") { command_rdns( $nick, $target, $what[0] ); }
        when ("eval") { command_eval( $nick, $target, join( ' ', @what ) ); }
        when ("version") { command_version( $nick, $target ); }
        when ("choose") { command_choose( $nick, $target, join( ' ', @what ) ); }
        when ("phoneletters") { command_phoneLetters( $nick, $target, join( ' ', @what ) ); }
    }
}

sub irc_ctcp_action {
    my ($who, $target, $action) = @_[ARG0 .. ARG2];
    my ($nick, $address) = ( split /!/, $who );
    $target = $target->[0];

    doLog( "* <$nick/$target> $action", 'irc' );

    if( $action =~ /slaps (\w+) .*with (a|some|his|her) (\w+ )?(\w+)/ ) {
        my ($victim, $adjective, $noun) = ($1, $3, $4);
        my $myNoun = int( rand(10) );
        given ( $myNoun ) {
            when (0) { $myNoun = 'an episode of Lost'; }
            when (1) { $myNoun = 'the river'; }
            when (2) { $myNoun = 'the street'; }
            when (3) { $myNoun = 'a brothel'; }
            when (4) { $myNoun = 'SnoFox\'s mom'; }
            when (5) { $myNoun = 'the sewer'; }
            when (6) { $myNoun = 'Nikki\'s food bowl'; }
            when (7) { $myNoun = 'a firey fire'; }
            when (8) { $myNoun = 'the path of a flaming Volkswagon'; }
            when (9) { $myNoun = 'a taco'; }
            when (10) { $myNoun = 'Super Mario World'; }
        }
        doAction( $target, "saves $victim by catching the $noun and throwing it into $myNoun." );
    }
    return;
}

sub irc_raw {
    my $string = $_[ARG0];

    if( uc( ( split( / / , $string ) )[1] ) ne 'PRIVMSG' ) {
        doLog( '-> ' . $string, 'irc_raw' );
    }
}

sub irc_raw_out {
    my $string = $_[ARG0];

    print "Raw out\n";
    doLog( '<- ' . $string, 'irc_raw' );
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

sub doLog {
    my ($string, $level, $target) = @_;
    # $target is currently unused
    
    print '[' . strftime('%H:%m', localtime() ) . '] ' . $string . "\n";
}

sub command_host {
    my ($nick, $chan, $arg) = @_;

     if( $arg =~ /(\d{1,3}\.){3}\d{1,3}/ ) {
        command_rdns($nick, $chan, $arg);
        return;
    }

    my $ip = gethostbyname($arg);

    if( defined( $ip ) ) {
        use Socket;
        doMsg( $chan, "Master $nick, I have resolved $arg to " . inet_ntoa($ip) );
    } else {
        doMsg( $chan, "Master $nick, I cannot resolve $arg. Perhaps it does not exist?" );
    }
}

sub command_rdns {
    my ($nick, $chan, $arg) = @_;
    use Socket;
    my $hostname = gethostbyaddr( inet_aton( $arg ), AF_INET );

    if( defined( $hostname ) ) {
        doMsg( $chan, "Master $nick, $arg has the reverse DNS record of $hostname" );
    } else {
        doMsg( $chan, "Master $nick, $arg does not appear to have an active reverse DNS record." );
    }
}

sub command_eval {
    my ($nick, $chan, $args) = @_;

    if( !$DEVELOPMENT ) {
        doMsg( $chan, "I apologize, $nick. However, I am directed not to issue the EVAL command under any circumstances." );
    }

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

sub command_version {
    my ($nick, $chan) = @_;

    if( defined($version) ) {
        doMsg( $chan, 'Master ' . $nick . ', according to my records, my software version is Git commit ID ' . $version );
    } else {
        doMsg( $chan, 'Master ' . $nick . ', according to my records, my software version is pre-alpha.' );
    }
}

sub command_choose {
    my ($nick, $chan, $args) = @_;
    
    my @options = split( / or / , $args );

    my $pick = int( rand($#options + 1) );

    doMsg( $chan, "Master $nick, I recommend the following option: $options[$pick]" );
}

sub command_phoneLetters {
    my ($nick, $chan, $args) = @_;

    my $output = lc( $args );
    $output =~ s/[abc]/2/g;
    $output =~ s/[def]/3/g;
    $output =~ s/[ghi]/4/g;
    $output =~ s/[jkl]/5/g;
    $output =~ s/[mno]/6/g;
    $output =~ s/[pqrs]/7/g;
    $output =~ s/[tuv]/8/g;
    $output =~ s/[wxyz]/9/g;

    doMsg( $chan, "Master $nick, \"$args\" maps to $output" );
}

#!/usr/bin/perl
use strict;
use lib '/home/darren/perl_lib';

require CGI::Portable;
my $globals = CGI::Portable->new();

require CGI::WPM::SimpleUserIO;
my $io = CGI::WPM::SimpleUserIO->new( 1 );
$io->give_user_input_to_cgi_portable( $globals );

$globals->current_user_path_level( 1 );
$globals->call_component( 'FrameSet' );

$io->send_user_output_from_cgi_portable( $globals );

1;

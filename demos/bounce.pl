#!/usr/bin/perl
use strict;
use lib '/home/darren/perl_lib';

require CGI::Portable;
my $globals = CGI::Portable->new();

require CGI::WPM::SimpleUserIO;
my $io = CGI::WPM::SimpleUserIO->new( 1 );
$io->give_user_input_to_cgi_portable( $globals );

my %CONFIG = ();

$globals->set_prefs( \%CONFIG );
$globals->call_component( 'CGI::WPM::Redirect' );

$io->send_user_output_from_cgi_portable( $globals );

1;

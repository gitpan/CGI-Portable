#!/usr/bin/perl
use strict;
use lib '/home/darren/perl_lib';

require CGI::Portable;
my $globals = CGI::Portable->new();

use Cwd;
$globals->file_path_root( cwd() );  # let us default to current working dir
$globals->file_path_delimiter( $^O=~/Mac/i ? ":" : $^O=~/Win/i ? "\\" : "/" );

my %CONFIG = ( filename => 'static.html' );

$globals->set_prefs( \%CONFIG );
$globals->call_component( 'CGI::WPM::Static' );

require CGI::WPM::SimpleUserIO;
my $io = CGI::WPM::SimpleUserIO->new();
$io->send_user_output_from_cgi_portable( $globals );

1;

#!/usr/bin/perl
use strict;
use lib '/home/darren/perl_lib';

require CGI::Portable;
my $globals = CGI::Portable->new();

use Cwd;
$globals->file_path_root( cwd() );  # let us default to current working dir
$globals->file_path_delimiter( $^O=~/Mac/i ? ":" : $^O=~/Win/i ? "\\" : "/" );

require CGI::WPM::SimpleUserIO;
my $io = CGI::WPM::SimpleUserIO->new( 1 );
$io->give_user_input_to_cgi_portable( $globals );

my %CONFIG = (
	title => 'Index of the World',
	author => 'Jules Verne',
	created => 'Version 1.0, first created 1993 June 24',
	updated => 'Version 3.1, last modified 2000 November 18',
	filename => 'jv_world.txt',
	segments => 5,
);

$globals->current_user_path_level( 1 );
$globals->set_prefs( \%CONFIG );
$globals->call_component( 'CGI::WPM::SegTextDoc' );

$io->send_user_output_from_cgi_portable( $globals );

1;

#!/usr/bin/perl
use strict;
use lib '/home/darren/perl_lib';

# make new framework

require CGI::Portable;
my $globals = CGI::Portable->new();

# set where our files are today

use Cwd;
$globals->file_path_root( cwd() );  # let us default to current working directory
$globals->file_path_delimiter( $^O=~/Mac/i ? ":" : $^O=~/Win/i ? "\\" : "/" );

# fetch the web user's input from environment or command line
# store user input in CGI::Portable, remem script url in call-back urls

require CGI::WPM::SimpleUserIO;
my $io = CGI::WPM::SimpleUserIO->new( 1 );
$io->give_user_input_to_cgi_portable( $globals );

# set up component context including file prefs and user path level

my $content = $globals->make_new_context();
$content->current_user_path_level( 1 );
$content->set_prefs( 'config.pl' );

# run our main program to do all the real work, now that its sandbox is ready
# it will make an error screen if the main program failed for some reason

$content->call_component( 'Aardvark' );

# retrieve user output or error screen from the sandbox

$globals->take_context_output( $content );

# send the user output

$io->send_user_output_from_cgi_portable( $globals );

1;

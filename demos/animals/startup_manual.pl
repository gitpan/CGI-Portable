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

# fetch the web user's input, set url base this script uses in call-backs

$globals->url_base( "http://$ENV{HTTP_HOST}$ENV{SCRIPT_NAME}" );
$globals->user_path( $ENV{'PATH_INFO'} );
$globals->user_query( $ENV{'QUERY_STRING'} );
if( $ENV{'REQUEST_METHOD'} eq 'POST' ) {
	my $post_data;
	read( STDIN, $post_data, $ENV{'CONTENT_LENGTH'} );
	chomp( $post_data );
	$globals->user_post( $post_data );
}
$globals->user_cookies( $ENV{'HTTP_COOKIE'} || $ENV{'COOKIE'} );

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

print STDOUT "Status: @{[$globals->http_status_code()]}\n";
print STDOUT "Content-type: @{[$globals->http_content_type()]}\n";
if( my $url = $globals->http_redirect_url() ) {
	print STDOUT "Uri: $url\nLocation: $url\n";
}
print STDOUT "\n".$globals->page_as_string();

1;

=head1 NAME

CGI::WPM::SimpleUserIO - Abstracted user input/output in CGI, mod_perl, cmd line.

=cut

######################################################################

package CGI::WPM::SimpleUserIO;
require 5.004;

# Copyright (c) 1999-2001, Darren R. Duncan. All rights reserved. This module is
# free software; you can redistribute it and/or modify it under the same terms as
# Perl itself.  However, I do request that this copyright information remain
# attached to the file.  If you modify this module and redistribute a changed
# version then please attach a note listing the modifications.

use strict;
use vars qw($VERSION @ISA);
$VERSION = '0.42';

######################################################################

=head1 DEPENDENCIES

=head2 Perl Version

	5.004

=head2 Standard Modules

	Apache (when running under mod_perl only)

=head2 Nonstandard Modules

	CGI::Portable 0.42 (when using the *_cgi_portable() methods)

=head1 SYNOPSIS

=head2 Content of thin shell "startup_suio.pl" for CGI, mod_perl, command line:

I<This example is modified from the startup_manual.pl example in CGI::Portable 
to use this class instead of doing user input/output manually.  
This example uses all of the other example files from CGI::Portable as is.>

	#!/usr/bin/perl
	use strict;

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

=head1 DESCRIPTION

This Perl 5 object class provides some convenience methods for getting user input 
and sending user output by abstracting away the exact method of these actions.  
This class is designed to get input from both web users through the environment 
and from users debugging their scripts on the command line; user input can be 
gotten from either shell arguments and through standard input.  This class is 
designed to sense when it is running under mod_perl and use the appropriate 
Apache methods to send output; otherwise it prints to standard output which is 
suitable for both CGI and the command line.  This class is intended to be used 
with CGI::Portable, which doesn't do any user input or output by itself, but 
you can also use it independently.

=cut

######################################################################

# These properties are set only once because they correspond to user 
# input that can only be gathered prior to this program starting up.
my $KEY_USER_PATH_INFO_STR = 'user_path_info_str';
my $KEY_USER_QUERY_STR     = 'user_query_str';
my $KEY_USER_POST_STR      = 'user_post_str';
my $KEY_IS_OVERSIZE_POST   = 'is_oversize_post';
my $KEY_USER_COOKIES_STR   = 'user_cookies_str';

# Constant values used in this class go here:
my $MAX_CONTENT_LENGTH = 100_000;  # currently limited to 100 kbytes

######################################################################

=head1 SYNTAX

This class does not export any functions or methods, so you need to call them
using object notation.  This means using B<Class-E<gt>function()> for functions
and B<$object-E<gt>method()> for methods.  If you are inheriting this class for
your own modules, then that often means something like B<$self-E<gt>method()>. 

=head1 FUNCTIONS AND METHODS

=head2 new([ GATHER_INPUT_NOW ])

This function creates a new CGI::WPM::SimpleUserIO object and returns it.  If 
the optional parameter GATHER_INPUT_NOW is true then this method also calls 
gather_user_input() for you.

=cut

######################################################################

sub new {
	my $class = shift( @_ );
	my $self = bless( {}, ref($class) || $class );
	$_[0] and $self->gather_user_input( @_ );
	return( $self );
}

######################################################################

=head2 gather_user_input()

This method will gather several types of user input from %ENV, <STDIN>, and @ARGV
where appropriate.  If $ENV{REQUEST_METHOD} is one of [GET,HEAD,POST] then this
method assumes we are online and gathers the "path info", "query string", post
data, and "http cookie" from the environment and standard in.  Only
$ENV{CONTENT_LENGTH} of post data is read normally, and none is read if the
content length is over 100KB of data; in the latter case, this object's "is
oversize post" property is set to true.  This method should only be called once
when online or the method may hang when trying to read more post data.  If this
method assumes we are not online then it will assume it is being debugged on the
command line.  This method will then first check $ARGV[1] for content, and if
present it will take @ARGV elements 1 thru 4 and assign them to the first 4
properties above.  ($ARGV[0] is reserved for the caller's use, such as to hold an
http host name.)  If we are offline and $ARGV[1] is empty then we will attempt to
read the 4 properties from standard in; one line is read for each and each is
preceeded with a user prompt on STDERR.  None of the gathered user input is 
parsed; you can retrieve the raw strings with the next 5 methods.

=cut

######################################################################

sub gather_user_input {
	my $self = shift( @_ );
	my ($path_info, $query, $post, $oversize, $cookies);

	if( $ENV{'REQUEST_METHOD'} =~ /^(GET|HEAD|POST)$/ ) {
		$path_info = $ENV{'PATH_INFO'};

		$query = $ENV{'QUERY_STRING'};
		$query ||= $ENV{'REDIRECT_QUERY_STRING'};
		
		if( $ENV{'CONTENT_LENGTH'} <= $MAX_CONTENT_LENGTH ) {
			read( STDIN, $post, $ENV{'CONTENT_LENGTH'} );
			chomp( $post );
		} else {  # post too large, error condition, post not taken
			$oversize = $MAX_CONTENT_LENGTH;
		}

		$cookies = $ENV{'HTTP_COOKIE'} || $ENV{'COOKIE'};

	} elsif( $ARGV[1] ) {  # allow caller to save $ARGV[0] for the http_host
		$path_info = $ARGV[1];
		$query = $ARGV[2];
		$post = $ARGV[3];
		$cookies = $ARGV[4];

	} else {
		print STDERR "offline mode: enter user path info on standard input\n";
		print STDERR "it must be all on one line\n";
		$path_info = <STDIN>;
		chomp( $path_info );

		print STDERR "offline mode: enter user query on standard input\n";
		print STDERR "it must be query-escaped and all on one line\n";
		$query = <STDIN>;
		chomp( $query );

		print STDERR "offline mode: enter user post on standard input\n";
		print STDERR "it must be query-escaped and all on one line\n";
		$post = <STDIN>;
		chomp( $post );

		print STDERR "offline mode: enter user cookies on standard input\n";
		print STDERR "they must be cookie-escaped and all on one line\n";
		$cookies = <STDIN>;
		chomp( $cookies );
	}

	$self->{$KEY_USER_PATH_INFO_STR} = $path_info;
	$self->{$KEY_USER_QUERY_STR}     = $query;
	$self->{$KEY_USER_POST_STR}      = $post;
	$self->{$KEY_IS_OVERSIZE_POST}   = $oversize;
	$self->{$KEY_USER_COOKIES_STR}   = $cookies;
}

######################################################################

=head2 user_path_info_str()

This method returns the raw "path_info" string.

=head2 user_query_str()

This method returns the raw "query_string".

=head2 user_post_str()

This method returns the raw "post" data as a string.

=head2 is_oversize_post()

This method returns true if $ENV{CONTENT_LENGTH} was over 100,000KB.

=head2 user_cookies_str()

This method returns the raw "http_cookie" string.

=cut

######################################################################

sub user_path_info_str { $_[0]->{$KEY_USER_PATH_INFO_STR} }
sub user_query_str     { $_[0]->{$KEY_USER_QUERY_STR}     }
sub user_post_str      { $_[0]->{$KEY_USER_POST_STR}      }
sub is_oversize_post   { $_[0]->{$KEY_IS_OVERSIZE_POST}   }
sub user_cookies_str   { $_[0]->{$KEY_USER_COOKIES_STR}   }

######################################################################

=head2 url_base()

This method constructs a probable "base url" that the current script was called 
as on the web.  It is approximately equal to "http://" + $ENV{HTTP_HOST} + ":"
$ENV{SERVER_PORT} + $ENV{SCRIPT_NAME}.  The port is omitted if it is 80 or 
undefined.  The http_host defaults to server_name and then "localhost" if it or 
server_name isn't defined.  The script_name is url-decoded.  This method's 
return value can be used in conjunction with appropriate path_info and 
query_string data to construct self-referencing urls that reinvoke this same 
script with or without persistant user input; post data can also be preserved 
with a form whose fields contain the post data and whose "action" url is this 
aforementioned self-referencing url.  Note that CGI::Portable can do the 
self-referencing details for you if provided with a base_url() and other data.

=cut

######################################################################

sub url_base {
	my $host = $ENV{'HTTP_HOST'} || $ENV{'SERVER_NAME'} || 'localhost';
	my $port = $ENV{'SERVER_PORT'} || 80;
	my $script = $ENV{'SCRIPT_NAME'};
	$script =~ tr/+/ /;
	$script =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;
	return( 'http://'.$host.($port != 80 ? ":$port" : '').$script );
}

######################################################################

=head2 server_is_mod_perl()

This method returns true if we seem to be running under mod_perl and false 
otherwise.  To determine that fact, we check $ENV{'GATEWAY_INTERFACE'} to see 
if it begins with "CGI-Perl"; mod_perl is guaranteed to set this, according to 
the documentation.

=cut

######################################################################

sub server_is_mod_perl {
	return( $ENV{'GATEWAY_INTERFACE'} =~ /^CGI-Perl/ );
}

######################################################################

=head2 give_user_input_to_cgi_portable( GLOBALS[, PATH_IN_QUERY] )

This method should be called after gather_user_input() is, since it makes use 
of the user input gathered there.  This method takes a CGI::Portable object as 
its first argument, GLOBALS, and feeds it all of the user input that it can.  
Specifically it sets: user_query(), user_post(), user_cookies(), user_path().  
This method will also feed the object an appropriate value for url_base().  
This method will also configure the CGI::Portable object to use either the 
path info or query string parts of urls to store its user path.  By default, 
CGI::Portable uses the path info, and if this method is not called with a 
second argument then it assumes the same; no changes are made.  If, however, 
the scalar argument PATH_IN_QUERY is true, then this method will change 4 
properties of the CGI::Portable object besides the user path from their defaults: 
url_path_is_in_path_info(), url_path_is_in_query(), url_path_query_param_name(), 
and the user query itself; once the user path has been retrieved from the user 
query, it is deleted from the user query (this helps with recall url issues).  
When PATH_IN_QUERY is true, it is also assumed to be the name of the query 
parameter whose value is the user path.  By using this method, you stand to cut 
down a fair bit on the config shell code you need to run CGI::Portable with.

=cut

######################################################################

sub give_user_input_to_cgi_portable {
	my ($self, $globals, $path_in_query) = @_;
	$globals->url_base( $self->url_base() );
	$globals->user_query( $self->user_query_str() );
	$globals->user_post( $self->user_post_str() );
	$globals->user_cookies( $self->user_cookies_str() );
	if( $path_in_query ) {
		$globals->url_path_is_in_path_info( 0 );
		$globals->url_path_is_in_query( 1 );
		$globals->url_path_query_param_name( $path_in_query );
		$globals->user_path( lc( $globals->user_query_param( $path_in_query ) ) );
		$globals->get_user_query_ref()->delete( $path_in_query );
	} else {
		$globals->user_path( $self->user_path_info_str() );
	}
}

######################################################################

=head2 send_user_output_from_cgi_portable( GLOBALS )

This method takes a CGI::Portable object as its first argument, GLOBALS, and
sends as much user output as possible to the user.  This method can handle all of
the output details that CGI::Portable stores except for http cookies, and the
misc headers support is limited.  Whereas, the status code, window target,
content type, redirect url, http body (binary or not), miscellaneous headers and
all parts of an html page response are handled by this method.  The status code
and content type default to '200 OK' and 'text/html' if not defined respectively.
However, the content type is not output if there is a redirect url.  If this
script is running under mod_perl then this method uses the Apache Request
object's send_cgi_header() method to send all the http headers; otherwise they
are printed to STDOUT.  The http body is printed to STDOUT regardless. This
method does not support NPH responses at this time, but should later. By using
this method, you stand to cut down a fair bit on the config shell code you need
to run CGI::Portable with.

=head2 send_quick_html_response( CONTENT )

This method takes a string containing an HTML document as its first argument, 
CONTENT, and sends an http response appropriate for an HTML document which 
includes CONTENT as the http body.  This method works under mod_perl and cgi 
but does not support NPH currently.

=head2 send_quick_redirect_response( URL )

This method takes a string containing an url as its first argument, URL, and 
sends an http redirection header to send the client browser to that url.  
This method works under mod_perl and cgi but does not support NPH currently.

=cut

######################################################################

sub send_user_output_from_cgi_portable {
	my ($self, $globals) = @_;
	my $status = $globals->http_status_code() || '200 OK';
	my $target = $globals->http_window_target();
	my $type = $globals->http_content_type() || 'text/html';
	my $url = $globals->http_redirect_url();
	my %misc = $globals->get_http_headers();
	my $content = $globals->http_body() || $globals->page_as_string();
	my $bin = $globals->http_body_is_binary();
	$self->_send_output( $status, $type, $url, \%misc, $target, $content, $bin );
}

sub send_quick_html_response {
	my ($self, $content) = @_;
	$self->_send_output( '200 OK', 'text/html', undef, {}, undef, $content );
}

sub send_quick_redirect_response {
	my ($self, $url) = @_;
	$self->_send_output( '301 Moved', undef, $url, {} );
}

# _send_output( STATUS, TYPE, [URL], MISC, [TARGET[, CONTENT[, IS_BINARY]]] )
# This private method is used to implement all the send_*() methods above, 
# and works under both mod_perl and cgi.  It currently does not support NPH 
# responses but that should be added in the future.

sub _send_output {
	my ($self, $status, $type, $url, $misc, $target, $content, $is_binary) = @_;

	my @header = ("Status: $status");
	$target and push( @header, "Window-Target: $target" );
	push( @header, $url ? "Location: $url" : "Content-Type: $type" );
	%{$misc} and push( @header, map { "$_: $misc->{$_}" } sort keys %{$misc} );
	my $endl = "\015\012";  # cr + lf
	my $header = join( $endl, @header ).$endl.$endl;

	if( $self->server_is_mod_perl() ) {
		require Apache;
		$| = 1;
		my $req = Apache->request();
		$req->send_cgi_header( $header );
	
	} else {
		print STDOUT $header;
	}
	
	$is_binary and binmode( STDOUT );
	print STDOUT $content;
}

######################################################################

1;
__END__

=head1 AUTHOR

Copyright (c) 1999-2001, Darren R. Duncan. All rights reserved. This module is
free software; you can redistribute it and/or modify it under the same terms as
Perl itself.  However, I do request that this copyright information remain
attached to the file.  If you modify this module and redistribute a changed
version then please attach a note listing the modifications.

I am always interested in knowing how my work helps others, so if you put this
module to use in any of your own code then please send me the URL.  Also, if you
make modifications to the module because it doesn't work the way you need, please
send me a copy so that I can roll desirable changes into the main release.

Address comments, suggestions, and bug reports to B<perl@DarrenDuncan.net>.

=head1 SEE ALSO

perl(1), CGI::Portable, Apache.

=cut

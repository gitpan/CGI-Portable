=head1 NAME

CGI::Portable::Request - Stores user input, makes self-referencing urls

=cut

######################################################################

package CGI::Portable::Request;
require 5.004;

# Copyright (c) 1999-2001, Darren R. Duncan. All rights reserved. This module is
# free software; you can redistribute it and/or modify it under the same terms as
# Perl itself.  However, I do request that this copyright information remain
# attached to the file.  If you modify this module and redistribute a changed
# version then please attach a note listing the modifications.

use strict;
use vars qw($VERSION);
$VERSION = '0.43';

######################################################################

=head1 DEPENDENCIES

=head2 Perl Version

	5.004

=head2 Standard Modules

	I<none>

=head2 Nonstandard Modules

	File::VirtualPath 1.0
	CGI::MultiValuedHash 1.07

=cut

######################################################################

use File::VirtualPath 1.0;
use CGI::MultiValuedHash 1.07;

######################################################################

=head1 SYNOPSIS

I<See CGI::Portable, which is a subclass of this.>

=head1 DESCRIPTION

This class is designed to be inherited by CGI::Portable and implements some of 
that module's functionality; however, this class can also be used by itself.  
The split of functionality between several modules is intended to emphasize the 
fact that CGI::Portable is doing several tasks in parallel that are related but 
distinct, so you have more flexability to use what you need and not carry around 
what you don't use.  Each module has the POD for all methods it implements.

This class implements several distinct but closely related "input" properties,
the "user input", and the "url constructor", which store several kinds of input
from the web user and store pieces of new self-referencing urls respectively.
Please see USER INPUT OVERVIEW, MAKING NEW URLS OVERVIEW, and RECALL URLS
OVERVIEW below for a conceptual explanation of what these are for and how to use
them.

=head1 MAKING NEW URLS OVERVIEW

This class implements methods that manage several "url constructor" properties, 
which are designed to store components of the various information needed to make
new urls that call this script back in order to change from one interface screen
to another.  When the program is reinvoked with one of these urls, this
information becomes part of the user input, particularly the "user path" and
"user query".  You normally use the url_as_string() method to do the actual
assembly of these components, but the various "recall" methods also pay attention
to them.

=head1 RECALL URLS OVERVIEW

This class implements methods that are designed to make HTML for the user to
reinvoke this program with their input intact.  They pay attention to both the
current user input and the current url constructor properties.  Specifically,
these methods act like url_as_string() in the way they use most url constructor
properties, but they use the user path and user query instead of the url path and
url query.

=head1 USER INPUT OVERVIEW

This class implements methods that manage several "user input" properties, 
which include: "user path", "user query", "user post", and "user cookies".  
These properties store parsed copies of the various information that the web 
user provided when invoking this program instance.  Note that you should not 
modify the user input in your program, since the recall methods depend on them.

This class does not gather any user input itself, but expects your thin program
instance shell to do that and hand the data to this class prior to starting the
program core.  The rationale is both for keeping this class simpler and for
keeping it compatible with all types of web servers instead of just the ones it
knows about.  So it works equally well with CGI under any server or mod_perl or
when your Perl is its own web server or when you are debugging on the command 
line.  This class does know how to *parse* some url-encoded strings, however.

The kind of input you need to gather depends on what your program uses, but it
doesn't hurt to get more.  If you are in a CGI environment then you often get
user input from the following places: 1. $ENV{QUERY_STRING} for the query string
-- pass to user_query(); 2. <STDIN> for the post data -- pass to user_post(); 3.
$ENV{HTTP_COOKIE} for the raw cookies -- pass to user_cookies(); 4. either
$ENV{PATH_INFO} or a query parameter for the virtual web resource path -- pass to
user_path().  If you are in mod_perl then you call Apache methods to get the user
input.  If you are your own server then the incoming HTTP headers contain 
everything except the post data, which is in the HTTP body.  If you are on the 
command line then you can look in @ARGV or <STDIN> as is your preference.

The virtual web resource path is a concept with CGI::Portable designed to 
make it easy for different user interface pages of your program to be identified 
and call each other in the web environment.  The idea is that all the interface 
components that the user sees have a unique uri and can be organized 
hierarchically like a tree; by invoking your program with a different "path", 
the user indicates what part of the program they want to use.  It is analogous 
to choosing different html pages on a normal web site because each page has a 
separate uri on the server, and each page calls others by using different uris.  
What makes the virtual paths different is that each uri does not correspond to 
a different file; the user just pretends they do.  Ultimately you have control 
over what your program does with any particular virtual "user path".

The user path property is a File::VirtualPath object, and the other user input 
properties are each CGI::MultiValuedHash objects, so please see the respective 
POD for those classes to learn about their features.  Note that the user path 
always works in the virtual space and has no physical equivalent like file path.

=head1 DETAIL OF CURRENT HTTP REQUEST OVERVIEW

This class implements methods for storing a variety of details from the http 
request aside from those talked about in the "user input" section above.  
Under a CGI environment these would correspond to various %ENV keys.

=cut

######################################################################

# Names of properties for objects of this class are declared here:

# These properties say how to interperet user input and how to make new urls
my $KEY_URL_PIPI = 'url_pipi';  # boolean - true if path goes in PATH_INFO
my $KEY_URL_PIQU = 'url_piqu';  # boolean - true if path goes in a query param
my $KEY_URL_PQPN = 'url_pqpn';  # string - if path in query; this is param name

# These properties are used when making new self-referencing urls in output
my $KEY_URL_BASE = 'url_base';  # string - stores joined host, script_name, etc
my $KEY_URL_PATH = 'url_path';  # FVP - virtual path used in s-r urls
my $KEY_URL_QUER = 'url_quer';  # CMVH - holds query params to put in all urls

# These properties are set from the user input request
my $KEY_UI_PATH = 'ui_path';  # FVP - stores parsed path info from uri (usually)
my $KEY_UI_QUER = 'ui_quer';  # CMVH - stores parsed user input query from uri
my $KEY_UI_POST = 'ui_post';  # CMVH - stores parsed user input post (http body)
my $KEY_UI_COOK = 'ui_cook';  # CMVH - stores parsed user input cookies

# These properties are from the http request also
my $KEY_UI_METH = 'ui_meth';  # string - stores request method (GET/POST/HEAD)
my $KEY_UI_HOST = 'ui_host';  # string - stores virtual host domain of server
my $KEY_UI_PORT = 'ui_port';  # number - stores server port
my $KEY_UI_SCRI = 'ui_scri';  # string - stores base part of uri having filename
my $KEY_UI_REFE = 'ui_refe';  # string - stores referring url
my $KEY_UI_AGEN = 'ui_agen';  # string - stores user agent web browser
my $KEY_UI_RADD = 'ui_radd';  # string - stores remote IP address of web user
my $KEY_UI_RHOS = 'ui_rhos';  # string - stores remote host domain of web user

######################################################################

=head1 SYNTAX

This class does not export any functions or methods, so you need to call them
using object notation.  This means using B<Class-E<gt>function()> for functions
and B<$object-E<gt>method()> for methods.  If you are inheriting this class for
your own modules, then that often means something like B<$self-E<gt>method()>. 

=head1 CONSTRUCTOR FUNCTIONS AND METHODS AND CONTEXT SWITCHING

These functions and methods are involved in making new CGI::Portable::Request
objects, except the last one which combines two existing ones.  All five of them 
are present in both CGI::Portable and other classes designed to be inherited by 
it, including this one, because they implement its functionality.

=head2 new()

This function creates a new CGI::Portable::Request (or subclass) object and
returns it.

=head2 initialize()

This method is used by B<new()> to set the initial properties of objects that it
creates.

=head2 clone([ CLONE ])

This method initializes a new object to have all of the same properties of the
current object and returns it.  This new object can be provided in the optional
argument CLONE (if CLONE is an object of the same class as the current object);
otherwise, a brand new object of the current class is used.  Only object
properties recognized by CGI::Portable::Request are set in the clone; other
properties are not changed.

=head2 make_new_context([ CONTEXT ])

This method initializes a new object of the current class and returns it.  This
new object has some of the current object's properties, namely the "input"
properties, but lacks others, namely the "output" properties; the latter are
initialized to default values instead.  As with clone(), the new object can be
provided in the optional argument CONTEXT (if CONTEXT is an object of the same
class); otherwise a brand new object is used.  Only properties recognized by
CGI::Portable::Request are set in this object; others are not touched.

=head2 take_context_output( CONTEXT[, APPEND_LISTS[, SKIP_SCALARS]] )

This method takes another CGI::Portable::Request (or subclass) object as its
CONTEXT argument and copies some of its properties to this object, potentially
overwriting any versions already in this object.  If CONTEXT is not a valid
CGI::Portable::Request (or subclass) object then this method returns without
changing anything.  The properties that get copied are the "output" properties
that presumably need to work their way back to the user.  In other words, this
method copies everything that make_new_context() did not. If the optional boolean
argument APPEND_LISTS is true then any list-type properties, including arrays and
hashes, get appended to the existing values where possible rather than just
replacing them.  In the case of hashes, however, keys with the same names are
still replaced.  If the optional boolean argument SKIP_SCALARS is true then
scalar properties are not copied over; otherwise they will always replace any
that are in this object already.

=cut

######################################################################

sub new {
	my $class = shift( @_ );
	my $self = bless( {}, ref($class) || $class );
	$self->initialize( @_ );
	return( $self );
}

sub initialize {
	my ($self) = @_;

	$self->{$KEY_URL_PIPI} = 1;
	$self->{$KEY_URL_PIQU} = undef;
	$self->{$KEY_URL_PQPN} = 'path';

	$self->{$KEY_URL_BASE} = 'http://localhost/';
	$self->{$KEY_URL_PATH} = File::VirtualPath->new();
	$self->{$KEY_URL_QUER} = CGI::MultiValuedHash->new();

	$self->{$KEY_UI_PATH} = File::VirtualPath->new();
	$self->{$KEY_UI_QUER} = CGI::MultiValuedHash->new();
	$self->{$KEY_UI_POST} = CGI::MultiValuedHash->new();
	$self->{$KEY_UI_COOK} = CGI::MultiValuedHash->new();

	$self->{$KEY_UI_METH} = 'GET';
	$self->{$KEY_UI_HOST} = 'localhost';
	$self->{$KEY_UI_PORT} = 80;
	$self->{$KEY_UI_SCRI} = undef;
	$self->{$KEY_UI_REFE} = undef;
	$self->{$KEY_UI_AGEN} = undef;
	$self->{$KEY_UI_RADD} = '127.0.0.1';
	$self->{$KEY_UI_RHOS} = 'localhost';
}

sub clone {
	my ($self, $clone) = @_;
	ref($clone) eq ref($self) or $clone = bless( {}, ref($self) );

	$clone->{$KEY_URL_PIPI} = $self->{$KEY_URL_PIPI};
	$clone->{$KEY_URL_PIQU} = $self->{$KEY_URL_PIQU};
	$clone->{$KEY_URL_PQPN} = $self->{$KEY_URL_PQPN};

	$clone->{$KEY_URL_BASE} = $self->{$KEY_URL_BASE};
	$clone->{$KEY_URL_PATH} = $self->{$KEY_URL_PATH}->clone();
	$clone->{$KEY_URL_QUER} = $self->{$KEY_URL_QUER}->clone();

	$clone->{$KEY_UI_PATH} = $self->{$KEY_UI_PATH}->clone();
	$clone->{$KEY_UI_QUER} = $self->{$KEY_UI_QUER}->clone();
	$clone->{$KEY_UI_POST} = $self->{$KEY_UI_POST}->clone();
	$clone->{$KEY_UI_COOK} = $self->{$KEY_UI_COOK}->clone();

	$clone->{$KEY_UI_METH} = $self->{$KEY_UI_METH};
	$clone->{$KEY_UI_HOST} = $self->{$KEY_UI_HOST};
	$clone->{$KEY_UI_PORT} = $self->{$KEY_UI_PORT};
	$clone->{$KEY_UI_SCRI} = $self->{$KEY_UI_SCRI};
	$clone->{$KEY_UI_REFE} = $self->{$KEY_UI_REFE};
	$clone->{$KEY_UI_AGEN} = $self->{$KEY_UI_AGEN};
	$clone->{$KEY_UI_RADD} = $self->{$KEY_UI_RADD};
	$clone->{$KEY_UI_RHOS} = $self->{$KEY_UI_RHOS};

	return( $clone );
}

sub make_new_context {
	my ($self, $context) = @_;
	ref($context) eq ref($self) or $context = bless( {}, ref($self) );

	$context->{$KEY_URL_PIPI} = $self->{$KEY_URL_PIPI};
	$context->{$KEY_URL_PIQU} = $self->{$KEY_URL_PIQU};
	$context->{$KEY_URL_PQPN} = $self->{$KEY_URL_PQPN};

	$context->{$KEY_URL_BASE} = $self->{$KEY_URL_BASE};
	$context->{$KEY_URL_PATH} = $self->{$KEY_URL_PATH}->clone();
	$context->{$KEY_URL_QUER} = $self->{$KEY_URL_QUER}->clone();

	$context->{$KEY_UI_PATH} = $self->{$KEY_UI_PATH}->clone();
	$context->{$KEY_UI_QUER} = $self->{$KEY_UI_QUER}->clone();
	$context->{$KEY_UI_POST} = $self->{$KEY_UI_POST}->clone();
	$context->{$KEY_UI_COOK} = $self->{$KEY_UI_COOK}->clone();

	$context->{$KEY_UI_METH} = $self->{$KEY_UI_METH};
	$context->{$KEY_UI_HOST} = $self->{$KEY_UI_HOST};
	$context->{$KEY_UI_PORT} = $self->{$KEY_UI_PORT};
	$context->{$KEY_UI_SCRI} = $self->{$KEY_UI_SCRI};
	$context->{$KEY_UI_REFE} = $self->{$KEY_UI_REFE};
	$context->{$KEY_UI_AGEN} = $self->{$KEY_UI_AGEN};
	$context->{$KEY_UI_RADD} = $self->{$KEY_UI_RADD};
	$context->{$KEY_UI_RHOS} = $self->{$KEY_UI_RHOS};

	return( $context );
}

sub take_context_output {}
# This class' properties are all input, so this method does nothing.

######################################################################

=head1 METHODS FOR MAKING NEW SELF-REFERENCING URLS

These methods are accessors for the "url constructor" properties of this object,
which are designed to store components of the various information needed to make
new urls that call this script back in order to change from one interface screen
to another.  When the program is reinvoked with one of these urls, this
information becomes part of the user input, particularly the "user path" and
"user query".  You normally use the url_as_string() method to do the actual
assembly of these components, but the various "recall" methods also pay attention
to them.

=head2 url_path_is_in_path_info([ VALUE ])

This method is an accessor for the "url path is in path info" boolean property 
of this object, which it returns.  If VALUE is defined, this property is set 
to it.  If this property is true then the "url path" property will persist as 
part of the "path_info" portion of all self-referencing urls.
This property defaults to true.

=cut

######################################################################

sub url_path_is_in_path_info {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) {
		$self->{$KEY_URL_PIPI} = $new_value;
	}
	return( $self->{$KEY_URL_PIPI} );
}

######################################################################

=head2 url_path_is_in_query([ VALUE ])

This method is an accessor for the "url path is in query" boolean property 
of this object, which it returns.  If VALUE is defined, this property is set 
to it.  If this property is true then the "url path" property will persist as 
part of the "query_string" portion of all self-referencing urls.
This property defaults to false.

=cut

######################################################################

sub url_path_is_in_query {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) {
		$self->{$KEY_URL_PIQU} = $new_value;
	}
	return( $self->{$KEY_URL_PIQU} );
}

######################################################################

=head2 url_path_query_param_name([ VALUE ])

This method is an accessor for the "url path query param name" scalar property 
of this object, which it returns.  If VALUE is defined, this property is set 
to it.  If the url path persists as part of a query string, this method defines 
the name of the query parameter that the url path is the value for.
This property defaults to 'path'.

=cut

######################################################################

sub url_path_query_param_name {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) {
		$self->{$KEY_URL_PQPN} = $new_value;
	}
	return( $self->{$KEY_URL_PQPN} );
}

######################################################################

=head2 url_base([ VALUE ])

This method is an accessor for the "url base" scalar property of this object,
which it returns.  If VALUE is defined, this property is set to it.
When new urls are made, the "url base" is used unchanged as its left end.  
Normally it would consist of a protocol, host domain, port (optional), 
script name, and would look like "protocol://host[:port][script]".  
For example, "http://aardvark.net/main.pl" or "http://aardvark.net:450/main.pl".
This property defaults to "http://localhost/".

=cut

######################################################################

sub url_base {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) {
		$self->{$KEY_URL_BASE} = $new_value;
	}
	return( $self->{$KEY_URL_BASE} );
}

######################################################################

=head2 get_url_path_ref()

This method returns a reference to the url path object which you can then
manipulate directly with File::VirtualPath methods.

=head2 url_path([ VALUE ])

This method is an accessor to the url path, which it returns as an array ref.  
If VALUE is defined then this property is set to it; it can be an array of path
levels or a string representation.

=head2 url_path_string([ TRAILER ])

This method returns a string representation of the url path.  If the optional
argument TRAILER is true, then a "/" is appended.

=head2 navigate_url_path( CHANGE_VECTOR )

This method updates the url path by taking the current one and applying
CHANGE_VECTOR to it using the FVP's chdir() method. This method returns an array
ref having the changed url path.

=head2 child_url_path_string( CHANGE_VECTOR[, WANT_TRAILER] )

This method uses CHANGE_VECTOR to derive a new url path relative to the current
one and returns it as a string.  If WANT_TRAILER is true then the string has a
path delimiter appended; otherwise, there is none.

=cut

######################################################################

sub get_url_path_ref {
	return( $_[0]->{$KEY_URL_PATH} );  # returns ref for further use
}

sub url_path {
	my ($self, $new_value) = @_;
	return( $self->{$KEY_URL_PATH}->path( $new_value ) );
}

sub url_path_string {
	my ($self, $trailer) = @_;
	return( $self->{$KEY_URL_PATH}->path_string( $trailer ) );
}

sub navigate_url_path {
	my ($self, $chg_vec) = @_;
	$self->{$KEY_URL_PATH}->chdir( $chg_vec );
}

sub child_url_path_string {
	my ($self, $chg_vec, $trailer) = @_;
	return( $self->{$KEY_URL_PATH}->child_path_string( $chg_vec, $trailer ) );
}

######################################################################

=head2 get_url_query_ref()

This method returns a reference to the "url query" object which you can then
manipulate directly with CGI::MultiValuedHash methods.

=head2 url_query([ VALUE ])

This method is an accessor to the "url query", which it returns as a 
cloned CGI::MultiValuedHash object.  If VALUE is defined then it is used to 
initialize a new user query.

=head2 url_query_string()

This method url-encodes the url query and returns it as a string.

=head2 url_query_param( KEY[, VALUES] )

This method is an accessor for individual url query parameters.  If there are
any VALUES then this method stores them in the query under the name KEY and
returns a count of values now associated with KEY.  VALUES can be either an array
ref or a literal list and will be handled correctly.  If there are no VALUES then
the current value(s) associated with KEY are returned instead.  If this method is
called in list context then all of the values are returned as a literal list; in
scalar context, this method returns only the first value.  The 3 cases that this
method handles are implemented with the query object's [store( KEY, *), fetch(
KEY ), fetch_value( KEY )] methods, respectively.  (This method is designed to 
work like CGI.pm's param() method, if you like that sort of thing.)

=cut

######################################################################

sub get_url_query_ref {
	return( $_[0]->{$KEY_URL_QUER} );  # returns ref for further use
}

sub url_query {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) {
		$self->{$KEY_URL_QUER} = CGI::MultiValuedHash->new( 0, $new_value );
	}
	return( $self->{$KEY_URL_QUER}->clone() );
}

sub url_query_string {
	return( $_[0]->{$KEY_URL_QUER}->to_url_encoded_string() );
}

sub url_query_param {
	my $self = shift( @_ );
	my $key = shift( @_ );
	if( @_ ) {
		return( $self->{$KEY_URL_QUER}->store( $key, @_ ) );
	} elsif( wantarray ) {
		return( @{$self->{$KEY_URL_QUER}->fetch( $key ) || []} );
	} else {
		return( $self->{$KEY_URL_QUER}->fetch_value( $key ) );
	}
}

######################################################################

=head2 url_as_string([ CHANGE_VECTOR ])

This method assembles the various "url *" properties of this object into a
complete HTTP url and returns it as a string.  That is, it returns the cumulative
string representation of those properties.  This consists of a url_base(),
"path info", "query string", and would look like "base[info][?query]".
For example, "http://aardvark.net/main.pl/lookup/title?name=plant&cost=low".
Depending on your settings, the url path may be in the path_info or the 
query_string or none or both.  If the optional argument CHANGE_VECTOR is true 
then the result of applying it to the url path is used for the url path.  
The above example showed the url path, "/lookup/title", in the path_info.  
If it were in query_string instead then the url would look like 
"http://aardvark.net/main.pl?path=/lookup/title&name=plant&cost=low".

=cut

######################################################################

sub url_as_string {
	my ($self, $chg_vec) = @_;
	return( $self->_make_an_url( $self->url_query_string(), $chg_vec ? 
		$self->child_url_path_string( $chg_vec ) : $self->url_path_string() ) );
}

# _make_an_url( QUERY, PATH )
# This private method contains common code for some url-string-making methods. 
# The two arguments refer to the path and query information that the new url 
# will have.  This method combines these with the url base as appropriate, 
# taking into account the settings for where the path should go.

sub _make_an_url {
	my ($self, $query, $path) = @_;
	my ($base, $path_info, $query_string);
	$base = $self->{$KEY_URL_BASE};
	if( $self->{$KEY_URL_PIPI} ) {
		$path_info = $path;
		$query_string = $query;
	}
	if( $self->{$KEY_URL_PIQU} ) {
		$path_info = '';
		$query_string = "$self->{$KEY_URL_PQPN}=$path".
			($query ? "&$query" : '');
	}
	return( $base.$path_info.($query_string ? "?$query_string" : '') );
}

######################################################################

=head1 METHODS FOR MAKING RECALL URLS

These methods are designed to make HTML for the user to reinvoke this program 
with their input intact.  They pay attention to both the current user input and 
the current url constructor properties.  Specifically, these methods act like 
url_as_string() in the way they use most url constructor properties, but they 
use the user path and user query instead of the url path and url query.

=head2 recall_url()

This method creates a callback url that can be used to recall this program with 
all query information intact.  It is intended for use as the "action" argument 
in forms, or as the url for "try again" hyperlinks on error pages.  The format 
of this url is determined partially by the "url *" properties, including 
url_base() and anything describing where the "path" goes, if you use it.  
Post data is not replicated here; see the recall_button() method.

=head2 recall_hyperlink([ LABEL ])

This method creates an HTML hyperlink that can be used to recall this program 
with all query information intact.  The optional scalar argument LABEL defines 
the text that the hyperlink surrounds, which is the blue text the user will see.
LABEL defaults to "here" if not defined.  Post data is not replicated.  
The url in the hyperlink is produced by recall_url().

=head2 recall_button([ LABEL ])

This method creates an HTML form out of a button and some hidden fields which 
can be used to recall this program with all query and post information intact.  
The optional scalar argument LABEL defines the button label that the user sees.
LABEL defaults to "here" if not defined.  This form submits with "post".  
Query and path information is replicated in the "action" url, produced by 
recall_url(), and the post information is replicated in the hidden fields.

=head2 recall_html([ LABEL ])

This method selectively calls recall_button() or recall_hyperlink() depending 
on whether there is any post information in the user input.  This is useful 
when you want to use the least intensive option required to preserve your user 
input and you don't want to figure out the when yourself.

=cut

######################################################################

sub recall_url {
	my ($self) = @_;
	return( $self->_make_an_url( $self->user_query_string(), 
		$self->user_path_string() ) );
}

sub recall_hyperlink {
	my ($self, $label) = @_;
	defined( $label ) or $label = 'here';
	my $url = $self->recall_url();
	return( "<A HREF=\"$url\">$label</A>" );
}

sub recall_button {
	my ($self, $label) = @_;
	defined( $label ) or $label = 'here';
	my $url = $self->recall_url();
	my $fields = $self->get_user_post_ref()->to_html_encoded_hidden_fields();
	return( <<__endquote );
<FORM METHOD="post" ACTION="$url">
$fields
<INPUT TYPE="submit" NAME="" VALUE="$label">
</FORM>
__endquote
}

sub recall_html {
	my ($self, $label) = @_;
	return( $self->get_user_post_ref()->keys_count() ? 
		$self->recall_button( $label ) : $self->recall_hyperlink( $label ) );
}

######################################################################

=head1 METHODS FOR USER INPUT

These methods are accessors for the "user input" properties of this object, 
which include: "user path", "user query", "user post", and "user cookies".  
See the DESCRIPTION for more details.

=head2 get_user_path_ref()

This method returns a reference to the user path object which you can then
manipulate directly with File::VirtualPath methods.

=head2 user_path([ VALUE ])

This method is an accessor to the user path, which it returns as an array ref. 
If VALUE is defined then this property is set to it; it can be an array of path
levels or a string representation.

=head2 user_path_string([ TRAILER ])

This method returns a string representation of the user path. If the optional
argument TRAILER is true, then a "/" is appended.

=head2 user_path_element( INDEX[, NEW_VALUE] )

This method is an accessor for individual segments of the "user path" property of 
this object, and it returns the one at INDEX.  If NEW_VALUE is defined then 
the segment at INDEX is set to it.  This method is useful if you want to examine 
user path segments one at a time.  INDEX defaults to 0, meaning you are 
looking at the first segment, which happens to always be empty.  That said, this 
method will let you change this condition if you want to.

=head2 current_user_path_level([ NEW_VALUE ])

This method is an accessor for the number "current path level" property of the user 
input, which it returns.  If NEW_VALUE is defined, this property is set to it.  
If you want to examine the user path segments sequentially then this property 
tracks the index of the segment you are currently viewing.  This property 
defaults to 0, the first segment, which always happens to be an empty string.

=head2 inc_user_path_level()

This method will increment the "current path level" property by 1 so 
you can view the next path segment.  The new current value is returned.

=head2 dec_user_path_level()

This method will decrement the "current path level" property by 1 so 
you can view the previous path segment.  The new current value is returned.  

=head2 current_user_path_element([ NEW_VALUE ])

This method is an accessor for individual segments of the "user path" property of 
this object, the current one of which it returns.  If NEW_VALUE is defined then 
the current segment is set to it.  This method is useful if you want to examine 
user path segments one at a time in sequence.  The segment you are looking at 
now is determined by the current_user_path_level() method; by default you are 
looking at the first segment, which is always an empty string.  That said, this 
method will let you change this condition if you want to.

=cut

######################################################################

sub get_user_path_ref {
	return( $_[0]->{$KEY_UI_PATH} );  # returns ref for further use
}

sub user_path {
	my ($self, $new_value) = @_;
	return( $self->{$KEY_UI_PATH}->path( $new_value ) );
}

sub user_path_string {
	my ($self, $trailer) = @_;
	return( $self->{$KEY_UI_PATH}->path_string( $trailer ) );
}

sub user_path_element {
	my ($self, $index, $new_value) = @_;
	return( $self->{$KEY_UI_PATH}->path_element( $index, $new_value ) );
}

sub current_user_path_level {
	my ($self, $new_value) = @_;
	return( $self->{$KEY_UI_PATH}->current_path_level( $new_value ) );
}

sub inc_user_path_level {
	return( $_[0]->{$KEY_UI_PATH}->inc_path_level() );
}

sub dec_user_path_level {
	return( $_[0]->{$KEY_UI_PATH}->dec_path_level() );
}

sub current_user_path_element {
	my ($self, $new_value) = @_;
	return( $self->{$KEY_UI_PATH}->current_path_element( $new_value ) );
}

######################################################################

=head2 get_user_query_ref()

This method returns a reference to the user query object which you can then
manipulate directly with CGI::MultiValuedHash methods.

=head2 user_query([ VALUE ])

This method is an accessor to the user query, which it returns as a 
cloned CGI::MultiValuedHash object.  If VALUE is defined then it is used to 
initialize a new user query.

=head2 user_query_string()

This method url-encodes the user query and returns it as a string.

=head2 user_query_param( KEY[, VALUES] )

This method is an accessor for individual user query parameters.  If there are
any VALUES then this method stores them in the query under the name KEY and
returns a count of values now associated with KEY.  VALUES can be either an array
ref or a literal list and will be handled correctly.  If there are no VALUES then
the current value(s) associated with KEY are returned instead.  If this method is
called in list context then all of the values are returned as a literal list; in
scalar context, this method returns only the first value.  The 3 cases that this
method handles are implemented with the query object's [store( KEY, *), fetch(
KEY ), fetch_value( KEY )] methods, respectively.  (This method is designed to 
work like CGI.pm's param() method, if you like that sort of thing.)

=cut

######################################################################

sub get_user_query_ref {
	return( $_[0]->{$KEY_UI_QUER} );  # returns ref for further use
}

sub user_query {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) {
		$self->{$KEY_UI_QUER} = CGI::MultiValuedHash->new( 0, $new_value );
	}
	return( $self->{$KEY_UI_QUER}->clone() );
}

sub user_query_string {
	return( $_[0]->{$KEY_UI_QUER}->to_url_encoded_string() );
}

sub user_query_param {
	my $self = shift( @_ );
	my $key = shift( @_ );
	if( @_ ) {
		return( $self->{$KEY_UI_QUER}->store( $key, @_ ) );
	} elsif( wantarray ) {
		return( @{$self->{$KEY_UI_QUER}->fetch( $key ) || []} );
	} else {
		return( $self->{$KEY_UI_QUER}->fetch_value( $key ) );
	}
}

######################################################################

=head2 get_user_post_ref()

This method returns a reference to the user post object which you can then
manipulate directly with CGI::MultiValuedHash methods.

=head2 user_post([ VALUE ])

This method is an accessor to the user post, which it returns as a 
cloned CGI::MultiValuedHash object.  If VALUE is defined then it is used to 
initialize a new user post.

=head2 user_post_string()

This method url-encodes the user post and returns it as a string.

=head2 user_post_param( KEY[, VALUES] )

This method is an accessor for individual user post parameters.  If there are
any VALUES then this method stores them in the post under the name KEY and
returns a count of values now associated with KEY.  VALUES can be either an array
ref or a literal list and will be handled correctly.  If there are no VALUES then
the current value(s) associated with KEY are returned instead.  If this method is
called in list context then all of the values are returned as a literal list; in
scalar context, this method returns only the first value.  The 3 cases that this
method handles are implemented with the post object's [store( KEY, *), fetch(
KEY ), fetch_value( KEY )] methods, respectively.  (This method is designed to 
work like CGI.pm's param() method, if you like that sort of thing.)

=cut

######################################################################

sub get_user_post_ref {
	return( $_[0]->{$KEY_UI_POST} );  # returns ref for further use
}

sub user_post {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) {
		$self->{$KEY_UI_POST} = CGI::MultiValuedHash->new( 0, $new_value );
	}
	return( $self->{$KEY_UI_POST}->clone() );
}

sub user_post_string {
	return( $_[0]->{$KEY_UI_POST}->to_url_encoded_string() );
}

sub user_post_param {
	my $self = shift( @_ );
	my $key = shift( @_ );
	if( @_ ) {
		return( $self->{$KEY_UI_POST}->store( $key, @_ ) );
	} elsif( wantarray ) {
		return( @{$self->{$KEY_UI_POST}->fetch( $key ) || []} );
	} else {
		return( $self->{$KEY_UI_POST}->fetch_value( $key ) );
	}
}

######################################################################

=head2 get_user_cookies_ref()

This method returns a reference to the user cookies object which you can then
manipulate directly with CGI::MultiValuedHash methods.

=head2 user_cookies([ VALUE ])

This method is an accessor to the user cookies, which it returns as a 
cloned CGI::MultiValuedHash object.  If VALUE is defined then it is used to 
initialize a new user query.

=head2 user_cookies_string()

This method cookie-url-encodes the user cookies and returns them as a string.

=head2 user_cookie( NAME[, VALUES] )

This method is an accessor for individual user cookies.  If there are
any VALUES then this method stores them in the cookie with the name NAME and
returns a count of values now associated with NAME.  VALUES can be either an array
ref or a literal list and will be handled correctly.  If there are no VALUES then
the current value(s) associated with NAME are returned instead.  If this method is
called in list context then all of the values are returned as a literal list; in
scalar context, this method returns only the first value.  The 3 cases that this
method handles are implemented with the query object's [store( NAME, *), fetch(
NAME ), fetch_value( NAME )] methods, respectively.  (This method is designed to 
work like CGI.pm's param() method, if you like that sort of thing.)

=cut

######################################################################

sub get_user_cookies_ref {
	return( $_[0]->{$KEY_UI_COOK} );  # returns ref for further use
}

sub user_cookies {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) {
		$self->{$KEY_UI_COOK} = CGI::MultiValuedHash->new( 0, 
			$new_value, '; ', '&' );
	}
	return( $self->{$KEY_UI_COOK}->clone() );
}

sub user_cookies_string {
	return( $_[0]->{$KEY_UI_COOK}->to_url_encoded_string( '; ', '&' ) );
}

sub user_cookie {
	my $self = shift( @_ );
	my $name = shift( @_ );
	if( @_ ) {
		return( $self->{$KEY_UI_COOK}->store( $name, @_ ) );
	} elsif( wantarray ) {
		return( @{$self->{$KEY_UI_COOK}->fetch( $name ) || []} );
	} else {
		return( $self->{$KEY_UI_COOK}->fetch_value( $name ) );
	}
}

######################################################################

=head1 METHODS FOR DETAIL OF CURRENT HTTP REQUEST

These methods are accessors for many "http request" properties of this object.  
Four of the request properties are more special and are mentioned above in the 
"user input" section.
Under a CGI environment these would correspond to various %ENV keys.

=head2 request_method([ VALUE ])

This method is an accessor for the "request method" scalar property of this object,
which it returns.  If VALUE is defined, this property is set to it.

=head2 virtual_host([ VALUE ])

This method is an accessor for the "virtual host" scalar property of this object,
which it returns.  If VALUE is defined, this property is set to it.

=head2 server_port([ VALUE ])

This method is an accessor for the "server port" scalar property of this object,
which it returns.  If VALUE is defined, this property is set to it.

=head2 script_name([ VALUE ])

This method is an accessor for the "script name" scalar property of this object,
which it returns.  If VALUE is defined, this property is set to it.

=head2 referer([ VALUE ])

This method is an accessor for the "referer" scalar property of this object,
which it returns.  If VALUE is defined, this property is set to it.

=head2 user_agent([ VALUE ])

This method is an accessor for the "user agent" scalar property of this object,
which it returns.  If VALUE is defined, this property is set to it.

=head2 remote_addr([ VALUE ])

This method is an accessor for the "remote addr" scalar property of this object,
which it returns.  If VALUE is defined, this property is set to it.

=head2 remote_host([ VALUE ])

This method is an accessor for the "remote host" scalar property of this object,
which it returns.  If VALUE is defined, this property is set to it.

=cut

######################################################################

sub request_method {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) { $self->{$KEY_UI_METH} = $new_value; }
	return( $self->{$KEY_UI_METH} );
}

sub virtual_host {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) { $self->{$KEY_UI_HOST} = $new_value; }
	return( $self->{$KEY_UI_HOST} );
}

sub server_port {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) { $self->{$KEY_UI_PORT} = $new_value; }
	return( $self->{$KEY_UI_PORT} );
}

sub script_name {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) { $self->{$KEY_UI_SCRI} = $new_value; }
	return( $self->{$KEY_UI_SCRI} );
}

sub referer {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) { $self->{$KEY_UI_REFE} = $new_value; }
	return( $self->{$KEY_UI_REFE} );
}

sub user_agent {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) { $self->{$KEY_UI_AGEN} = $new_value; }
	return( $self->{$KEY_UI_AGEN} );
}

sub remote_addr {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) { $self->{$KEY_UI_RADD} = $new_value; }
	return( $self->{$KEY_UI_RADD} );
}

sub remote_host {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) { $self->{$KEY_UI_RHOS} = $new_value; }
	return( $self->{$KEY_UI_RHOS} );
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

perl(1), File::VirtualPath, CGI::MultiValuedHash, CGI::Portable.

=cut

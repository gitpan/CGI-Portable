=head1 NAME

CGI::Portable::Response - Stores user output; HTTP headers/body, HTML page pieces

=cut

######################################################################

package CGI::Portable::Response;
require 5.004;

# Copyright (c) 1999-2003, Darren R. Duncan.  All rights reserved.  This module
# is free software; you can redistribute it and/or modify it under the same terms
# as Perl itself.  However, I do request that this copyright information and
# credits remain attached to the file.  If you modify this module and
# redistribute a changed version then please attach a note listing the
# modifications.  This module is available "as-is" and the author can not be held
# accountable for any problems resulting from its use.

use strict;
use warnings;
use vars qw($VERSION);
$VERSION = '0.461';

######################################################################

=head1 DEPENDENCIES

=head2 Perl Version

	5.004

=head2 Standard Modules

	I<none>

=head2 Nonstandard Modules

	HTML::EasyTags 1.071  -- only required in page_as_string()

=head1 SYNOPSIS

I<See CGI::Portable, which is a subclass of this.>

=head1 DESCRIPTION

This class is designed to be inherited by CGI::Portable and implements some of 
that module's functionality; however, this class can also be used by itself.  
The split of functionality between several modules is intended to emphasize the 
fact that CGI::Portable is doing several tasks in parallel that are related but 
distinct, so you have more flexability to use what you need and not carry around 
what you don't use.  Each module has the POD for all methods it implements.

This class is designed to accumulate and assemble the components of an HTTP
response, complete with status code, content type, other headers, and a body. The
intent is for your core program to use these to store its user output, and then
your thin program config shell would actually send the page to the user. These
properties are initialized with values suitable for returning an HTML page.

Half of the functionality in this class is specialized for HTML responses, which
are assumed to be the dominant activity.  This class is designed to accumulate
and assemble the components of a new HTML page, complete with body, title, meta
tags, and cascading style sheets.  HTML assembly is done with the 
page_as_string() method.

The "http body" property is intended for use when you want to return raw content
of any type, whether it is text or image or other binary.  It is a complement for
the html assembling methods and should be left undefined if they are used.

=cut

######################################################################

# Names of properties for objects of this class are declared here:

# These properties would go in output HTTP headers and body
my $KEY_HTTP_STAT = 'http_stat';  # string - HTTP status code; first to output
my $KEY_HTTP_WITA = 'http_wita';  # string - stores Window-Target of output
my $KEY_HTTP_COTY = 'http_coty';  # string - stores Content-Type of outp
my $KEY_HTTP_REDI = 'http_redi';  # string - stores URL to redirect to
my $KEY_HTTP_COOK = 'http_cook';  # array - stores outgoing encoded cookies
my $KEY_HTTP_HEAD = 'http_head';  # hash - stores misc HTTP headers keys/values
my $KEY_HTTP_BODY = 'http_body';  # string - stores raw HTTP body if wanted
my $KEY_HTTP_BINA = 'http_bina';  # boolean - true if HTTP body is binary

# These properties will be combined into the output page if it is text/html
my $KEY_PAGE_PROL = 'page_prol';  # string - prologue tag or "doctype" at top
my $KEY_PAGE_TITL = 'page_titl';  # string - new HTML title
my $KEY_PAGE_AUTH = 'page_auth';  # string - new HTML author
my $KEY_PAGE_META = 'page_meta';  # hash - new HTML meta keys/values
my $KEY_PAGE_CSSR = 'page_cssr';  # array - new HTML css file urls
my $KEY_PAGE_CSSC = 'page_cssc';  # array - new HTML css embedded code
my $KEY_PAGE_HEAD = 'page_head';  # array - raw misc content for HTML head
my $KEY_PAGE_FATR = 'page_fatr';  # hash - attribs for optional HTML frameset tag
my $KEY_PAGE_FRAM = 'page_fram';  # array of hashes - list of frame attributes
my $KEY_PAGE_BATR = 'page_batr';  # hash - attribs for HTML body tag
my $KEY_PAGE_BODY = 'page_body';  # array - raw content for HTML body

######################################################################

=head1 SYNTAX

This class does not export any functions or methods, so you need to call them
using object notation.  This means using B<Class-E<gt>function()> for functions
and B<$object-E<gt>method()> for methods.  If you are inheriting this class for
your own modules, then that often means something like B<$self-E<gt>method()>. 

=head1 CONSTRUCTOR FUNCTIONS AND METHODS AND CONTEXT SWITCHING

These functions and methods are involved in making new CGI::Portable::Response
objects, except the last one which combines two existing ones.  All five of them 
are present in both CGI::Portable and other classes designed to be inherited by 
it, including this one, because they implement its functionality.

=head2 new()

This function creates a new CGI::Portable::Response (or subclass) object and
returns it.

=head2 initialize()

This method is used by B<new()> to set the initial properties of objects that it
creates.

=head2 clone([ CLONE ])

This method initializes a new object to have all of the same properties of the
current object and returns it.  This new object can be provided in the optional
argument CLONE (if CLONE is an object of the same class as the current object);
otherwise, a brand new object of the current class is used.  Only object
properties recognized by CGI::Portable::Response are set in the clone; other
properties are not changed.

=head2 make_new_context([ CONTEXT ])

This method initializes a new object of the current class and returns it.  This
new object has some of the current object's properties, namely the "input"
properties, but lacks others, namely the "output" properties; the latter are
initialized to default values instead.  As with clone(), the new object can be
provided in the optional argument CONTEXT (if CONTEXT is an object of the same
class); otherwise a brand new object is used.  Only properties recognized by
CGI::Portable::Response are set in this object; others are not touched.

=head2 take_context_output( CONTEXT[, LEAVE_SCALARS[, REPLACE_LISTS]] )

This method takes another CGI::Portable::Response (or subclass) object as its
CONTEXT argument and copies some of its properties to this object, potentially
overwriting any versions already in this object.  If CONTEXT is not a valid
CGI::Portable::Response (or subclass) object then this method returns without
changing anything.  The properties that get copied are the "output" properties
that presumably need to work their way back to the user.  In other words, this
method copies everything that make_new_context() did not.  This method will 
never copy any properties which are undefined scalars or empty lists, so a 
CONTEXT with no "output" properties set will not cause any changes.  If any 
scalar output properties of CONTEXT are defined, they will overwrite any 
defined corresponding properties of this object by default; however, if the 
optional boolean argument LEAVE_SCALARS is true, then the scalar values are 
only copied if the ones in this object are not defined.  If any list output 
properties of CONTEXT have elements, then they will be appended to 
any corresponding ones of this object by default, thereby preserving both 
(except with hash properties, where like hash keys will overwrite); 
however, if the optional boolean argument REPLACE_LISTS is true, then any 
existing list values are overwritten by any copied CONTEXT equivalents.

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

	$self->{$KEY_HTTP_STAT} = '200 OK';
	$self->{$KEY_HTTP_WITA} = undef;
	$self->{$KEY_HTTP_COTY} = 'text/html';
	$self->{$KEY_HTTP_REDI} = undef;
	$self->{$KEY_HTTP_COOK} = [];
	$self->{$KEY_HTTP_HEAD} = {};
	$self->{$KEY_HTTP_BODY} = undef;
	$self->{$KEY_HTTP_BINA} = undef;

	$self->{$KEY_PAGE_PROL} = undef;
	$self->{$KEY_PAGE_TITL} = undef;
	$self->{$KEY_PAGE_AUTH} = undef;
	$self->{$KEY_PAGE_META} = {};
	$self->{$KEY_PAGE_CSSR} = [];
	$self->{$KEY_PAGE_CSSC} = [];
	$self->{$KEY_PAGE_HEAD} = [];
	$self->{$KEY_PAGE_FATR} = {};
	$self->{$KEY_PAGE_FRAM} = [];
	$self->{$KEY_PAGE_BATR} = {};
	$self->{$KEY_PAGE_BODY} = [];
}

sub clone {
	my ($self, $clone) = @_;
	ref($clone) eq ref($self) or $clone = bless( {}, ref($self) );

	$clone->{$KEY_HTTP_STAT} = $self->{$KEY_HTTP_STAT};
	$clone->{$KEY_HTTP_WITA} = $self->{$KEY_HTTP_WITA};
	$clone->{$KEY_HTTP_COTY} = $self->{$KEY_HTTP_COTY};
	$clone->{$KEY_HTTP_REDI} = $self->{$KEY_HTTP_REDI};
	$clone->{$KEY_HTTP_COOK} = [@{$self->{$KEY_HTTP_COOK}}];
	$clone->{$KEY_HTTP_HEAD} = {%{$self->{$KEY_HTTP_HEAD}}};
	$clone->{$KEY_HTTP_BODY} = $self->{$KEY_HTTP_BODY};
	$clone->{$KEY_HTTP_BINA} = $self->{$KEY_HTTP_BINA};

	$clone->{$KEY_PAGE_PROL} = $self->{$KEY_PAGE_PROL};
	$clone->{$KEY_PAGE_TITL} = $self->{$KEY_PAGE_TITL};
	$clone->{$KEY_PAGE_AUTH} = $self->{$KEY_PAGE_AUTH};
	$clone->{$KEY_PAGE_META} = {%{$self->{$KEY_PAGE_META}}};
	$clone->{$KEY_PAGE_CSSR} = [@{$self->{$KEY_PAGE_CSSR}}];
	$clone->{$KEY_PAGE_CSSC} = [@{$self->{$KEY_PAGE_CSSC}}];
	$clone->{$KEY_PAGE_HEAD} = [@{$self->{$KEY_PAGE_HEAD}}];
	$clone->{$KEY_PAGE_FATR} = {%{$self->{$KEY_PAGE_FATR}}};
	$clone->{$KEY_PAGE_FRAM} = [map { {%{$_}} } @{$self->{$KEY_PAGE_FRAM}}];
	$clone->{$KEY_PAGE_BATR} = {%{$self->{$KEY_PAGE_BATR}}};
	$clone->{$KEY_PAGE_BODY} = [@{$self->{$KEY_PAGE_BODY}}];

	return( $clone );
}

sub make_new_context {
	my ($self, $context) = @_;
	ref($context) eq ref($self) or $context = bless( {}, ref($self) );

	$context->{$KEY_HTTP_STAT} = '200 OK';
	$context->{$KEY_HTTP_WITA} = undef;
	$context->{$KEY_HTTP_COTY} = 'text/html';
	$context->{$KEY_HTTP_REDI} = undef;
	$context->{$KEY_HTTP_COOK} = [];
	$context->{$KEY_HTTP_HEAD} = {};
	$context->{$KEY_HTTP_BODY} = undef;
	$context->{$KEY_HTTP_BINA} = undef;

	$context->{$KEY_PAGE_PROL} = undef;
	$context->{$KEY_PAGE_TITL} = undef;
	$context->{$KEY_PAGE_AUTH} = undef;
	$context->{$KEY_PAGE_META} = {};
	$context->{$KEY_PAGE_CSSR} = [];
	$context->{$KEY_PAGE_CSSC} = [];
	$context->{$KEY_PAGE_HEAD} = [];
	$context->{$KEY_PAGE_FATR} = {};
	$context->{$KEY_PAGE_FRAM} = [];
	$context->{$KEY_PAGE_BATR} = {};
	$context->{$KEY_PAGE_BODY} = [];

	return( $context );
}

sub take_context_output {
	my ($self, $context, $leave_scalars, $replace_lists) = @_;
	UNIVERSAL::isa( $context, 'CGI::Portable::Response' ) or return( 0 );

	if( $leave_scalars ) {
		defined( $self->{$KEY_HTTP_STAT} ) or 
			$self->{$KEY_HTTP_STAT} = $context->{$KEY_HTTP_STAT};
		defined( $self->{$KEY_HTTP_WITA} ) or 
			$self->{$KEY_HTTP_WITA} = $context->{$KEY_HTTP_WITA};
		defined( $self->{$KEY_HTTP_COTY} ) or 
			$self->{$KEY_HTTP_COTY} = $context->{$KEY_HTTP_COTY};
		defined( $self->{$KEY_HTTP_REDI} ) or 
			$self->{$KEY_HTTP_REDI} = $context->{$KEY_HTTP_REDI};
		defined( $self->{$KEY_HTTP_BODY} ) or 
			$self->{$KEY_HTTP_BODY} = $context->{$KEY_HTTP_BODY};
		defined( $self->{$KEY_HTTP_BINA} ) or 
			$self->{$KEY_HTTP_BINA} = $context->{$KEY_HTTP_BINA};
		defined( $self->{$KEY_PAGE_PROL} ) or 
			$self->{$KEY_PAGE_PROL} = $context->{$KEY_PAGE_PROL};
		defined( $self->{$KEY_PAGE_TITL} ) or 
			$self->{$KEY_PAGE_TITL} = $context->{$KEY_PAGE_TITL};
		defined( $self->{$KEY_PAGE_AUTH} ) or 
			$self->{$KEY_PAGE_AUTH} = $context->{$KEY_PAGE_AUTH};

	} else {
		defined( $context->{$KEY_HTTP_STAT} ) and 
			$self->{$KEY_HTTP_STAT} = $context->{$KEY_HTTP_STAT};
		defined( $context->{$KEY_HTTP_WITA} ) and 
			$self->{$KEY_HTTP_WITA} = $context->{$KEY_HTTP_WITA};
		defined( $context->{$KEY_HTTP_COTY} ) and 
			$self->{$KEY_HTTP_COTY} = $context->{$KEY_HTTP_COTY};
		defined( $context->{$KEY_HTTP_REDI} ) and 
			$self->{$KEY_HTTP_REDI} = $context->{$KEY_HTTP_REDI};
		defined( $context->{$KEY_HTTP_BODY} ) and 
			$self->{$KEY_HTTP_BODY} = $context->{$KEY_HTTP_BODY};
		defined( $context->{$KEY_HTTP_BINA} ) and 
			$self->{$KEY_HTTP_BINA} = $context->{$KEY_HTTP_BINA};
		defined( $context->{$KEY_PAGE_PROL} ) and 
			$self->{$KEY_PAGE_PROL} = $context->{$KEY_PAGE_PROL};
		defined( $context->{$KEY_PAGE_TITL} ) and 
			$self->{$KEY_PAGE_TITL} = $context->{$KEY_PAGE_TITL};
		defined( $context->{$KEY_PAGE_AUTH} ) and 
			$self->{$KEY_PAGE_AUTH} = $context->{$KEY_PAGE_AUTH};
	}

	if( $replace_lists ) {
		@{$context->{$KEY_HTTP_COOK}} and 
			$self->{$KEY_HTTP_COOK} = [@{$context->{$KEY_HTTP_COOK}}];
		@{$context->{$KEY_PAGE_CSSR}} and 
			$self->{$KEY_PAGE_CSSR} = [@{$context->{$KEY_PAGE_CSSR}}];
		@{$context->{$KEY_PAGE_CSSC}} and 
			$self->{$KEY_PAGE_CSSC} = [@{$context->{$KEY_PAGE_CSSC}}];
		@{$context->{$KEY_PAGE_HEAD}} and 
			$self->{$KEY_PAGE_HEAD} = [@{$context->{$KEY_PAGE_HEAD}}];
		@{$context->{$KEY_PAGE_FRAM}} and $self->{$KEY_PAGE_FRAM} = 
			[map { {%{$_}} } @{$context->{$KEY_PAGE_FRAM}}];
		@{$context->{$KEY_PAGE_BODY}} and 
			$self->{$KEY_PAGE_BODY} = [@{$context->{$KEY_PAGE_BODY}}];

		%{$context->{$KEY_HTTP_HEAD}} and 
			$self->{$KEY_HTTP_HEAD} = {%{$context->{$KEY_HTTP_HEAD}}};
		%{$context->{$KEY_PAGE_META}} and 
			$self->{$KEY_PAGE_META} = {%{$context->{$KEY_PAGE_META}}};
		%{$context->{$KEY_PAGE_FATR}} and 
			$self->{$KEY_PAGE_FATR} = {%{$context->{$KEY_PAGE_FATR}}};
		%{$context->{$KEY_PAGE_BATR}} and 
			$self->{$KEY_PAGE_BATR} = {%{$context->{$KEY_PAGE_BATR}}};

	} else {
		push( @{$self->{$KEY_HTTP_COOK}}, @{$context->{$KEY_HTTP_COOK}} );
		push( @{$self->{$KEY_PAGE_CSSR}}, @{$context->{$KEY_PAGE_CSSR}} );
		push( @{$self->{$KEY_PAGE_CSSC}}, @{$context->{$KEY_PAGE_CSSC}} );
		push( @{$self->{$KEY_PAGE_HEAD}}, @{$context->{$KEY_PAGE_HEAD}} );
		push( @{$self->{$KEY_PAGE_FRAM}}, 
			map { {%{$_}} } @{$context->{$KEY_PAGE_FRAM}} );
		push( @{$self->{$KEY_PAGE_BODY}}, @{$context->{$KEY_PAGE_BODY}} );

		@{$self->{$KEY_HTTP_HEAD}}{keys %{$context->{$KEY_HTTP_HEAD}}} = 
			values %{$context->{$KEY_HTTP_HEAD}};
		@{$self->{$KEY_PAGE_META}}{keys %{$context->{$KEY_PAGE_META}}} = 
			values %{$context->{$KEY_PAGE_META}};
		@{$self->{$KEY_PAGE_FATR}}{keys %{$context->{$KEY_PAGE_FATR}}} = 
			values %{$context->{$KEY_PAGE_FATR}};
		@{$self->{$KEY_PAGE_BATR}}{keys %{$context->{$KEY_PAGE_BATR}}} = 
			values %{$context->{$KEY_PAGE_BATR}};
	}
}

######################################################################

=head1 METHODS FOR MAKING NEW HTTP RESPONSES

These methods are designed to accumulate and assemble the components of an HTTP 
response, complete with status code, content type, other headers, and a body.  
See the DESCRIPTION for more details.

=head2 http_status_code([ VALUE ])

This method is an accessor for the "status code" scalar property of this object,
which it returns.  If VALUE is defined, this property is set to it.
This property is used in a new HTTP header to give the result status of the 
HTTP request that this program is serving.  It defaults to "200 OK" which means 
success and that the HTTP body contains the document they requested.
Unlike other HTTP header content, this property is special and must be the very 
first thing that the HTTP server returns, on a line like "HTTP/1.0 200 OK".
However, the property also may appear elsewhere in the header, on a line like 
"Status: 200 OK".

=cut

######################################################################

sub http_status_code {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) {
		$self->{$KEY_HTTP_STAT} = $new_value;
	}
	return( $self->{$KEY_HTTP_STAT} );
}

######################################################################

=head2 http_window_target([ VALUE ])

This method is an accessor for the "window target" scalar property of this object,
which it returns.  If VALUE is defined, this property is set to it.
This property is used in a new HTTP header to indicate which browser window or 
frame that this this HTTP response should be loaded into.  It defaults to the 
undefined value, meaning this response ends up in the same window/frame as the 
page that called it.  This property would be used in a line like 
"Window-Target: leftmenu".

=cut

######################################################################

sub http_window_target {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) {
		$self->{$KEY_HTTP_WITA} = $new_value;
	}
	return( $self->{$KEY_HTTP_WITA} );
}

######################################################################

=head2 http_content_type([ VALUE ])

This method is an accessor for the "content type" scalar property of this object,
which it returns.  If VALUE is defined, this property is set to it.
This property is used in a new HTTP header to indicate the document type that 
the HTTP body is, such as text or image.  It defaults to "text/html" which means 
we are returning an HTML page.  This property would be used in a line like 
"Content-Type: text/html".

=cut

######################################################################

sub http_content_type {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) {
		$self->{$KEY_HTTP_COTY} = $new_value;
	}
	return( $self->{$KEY_HTTP_COTY} );
}

######################################################################

=head2 http_redirect_url([ VALUE ])

This method is an accessor for the "redirect url" scalar property of this object,
which it returns.  If VALUE is defined, this property is set to it.
This property is used in a new HTTP header to indicate that we don't have the 
document that the user wants, but we do know where they can get it.  
If this property is defined then it contains the url we redirect to.  
This property would be used in a line like "Location: http://www.cpan.org".

=cut

######################################################################

sub http_redirect_url {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) {
		$self->{$KEY_HTTP_REDI} = $new_value;
	}
	return( $self->{$KEY_HTTP_REDI} );
}

######################################################################

=head2 get_http_cookies_ref()

This method is an accessor for the "http cookies" array property of this 
object, a reference to which it returns.  Cookies are used for simple data 
persistance on the client side, and are passed back and forth in the HTTP 
headers.  If this property is defined, then a "Set-Cookie" HTTP header would be 
made for each list element.  Each array element is treated like a scalar 
internally as this class assumes you will encode each cookie prior to insertion.

=head2 get_http_cookies()

This method returns a list containing "http cookies" list elements.  This list 
is returned literally in list context and as an array ref in scalar context.

=head2 set_http_cookies( VALUE )

This method allows you to set or replace the current "http cookies" list with a 
new one.  The argument VALUE can be either an array ref or scalar or literal list.

=head2 add_http_cookies( VALUES )

This method will take a list of encoded cookies in the argument VALUES and 
append them to the internal "http cookies" list property.  VALUES can be either 
an array ref or a literal list.

=cut

######################################################################

sub get_http_cookies_ref {
	return( $_[0]->{$KEY_HTTP_COOK} );  # returns ref for further use
}

sub get_http_cookies {
	my @list_copy = @{$_[0]->{$KEY_HTTP_COOK}};
	return( wantarray ? @list_copy : \@list_copy );
}

sub set_http_cookies {
	my $self = shift( @_ );
	my $ra_values = ref( $_[0] ) eq 'ARRAY' ? $_[0] : \@_;
	@{$self->{$KEY_HTTP_COOK}} = @{$ra_values};
}

sub add_http_cookies {
	my $self = shift( @_ );
	my $ra_values = ref( $_[0] ) eq 'ARRAY' ? $_[0] : \@_;
	push( @{$self->{$KEY_HTTP_COOK}}, @{$ra_values} );
}

######################################################################

=head2 get_http_headers_ref()

This method is an accessor for the "misc http headers" hash property of this
object, a reference to which it returns.  HTTP headers constitute the first of
two main parts of an HTTP response, and says things like the current date, server
type, content type of the document, cookies to set, and more.  Some of these have
their own methods, above, if you wish to use them.  Each key/value pair in the
hash would be used in a line like "Key: value".

=head2 get_http_headers([ KEY ])

This method allows you to get the "misc http headers" hash property of this
object. If KEY is defined then it is taken as a key in the hash and the
associated value is returned.  If KEY is not defined then the entire hash is
returned as a list; in scalar context this list is in a new hash ref.

=head2 set_http_headers( KEY[, VALUE] )

This method allows you to set the "misc http headers" hash property of this
object. If KEY is a valid HASH ref then all the existing headers information is
replaced with the new hash keys and values.  If KEY is defined but it is not a
Hash ref, then KEY and VALUE are inserted together into the existing hash.

=head2 add_http_headers( KEY[, VALUE] )

This method allows you to add key/value pairs to the "misc http headers" 
hash property of this object.  If KEY is a valid HASH ref then the keys and 
values it contains are inserted into the existing hash property; any like-named 
keys will overwrite existing ones, but different-named ones will coexist.
If KEY is defined but it is not a Hash ref, then KEY and VALUE are inserted 
together into the existing hash.

=cut

######################################################################

sub get_http_headers_ref {
	return( $_[0]->{$KEY_HTTP_HEAD} );  # returns ref for further use
}

sub get_http_headers {
	my ($self, $key) = @_;
	if( defined( $key ) ) {
		return( $self->{$KEY_HTTP_HEAD}->{$key} );
	}
	my %hash_copy = %{$self->{$KEY_HTTP_HEAD}};
	return( wantarray ? %hash_copy : \%hash_copy );
}

sub set_http_headers {
	my ($self, $first, $second) = @_;
	if( defined( $first ) ) {
		if( ref( $first ) eq 'HASH' ) {
			$self->{$KEY_HTTP_HEAD} = {%{$first}};
		} else {
			$self->{$KEY_HTTP_HEAD}->{$first} = $second;
		}
	}
}

sub add_http_headers {
	my ($self, $first, $second) = @_;
	if( defined( $first ) ) {
		if( ref( $first ) eq 'HASH' ) {
			@{$self->{$KEY_HTTP_HEAD}}{keys %{$first}} = values %{$first};
		} else {
			$self->{$KEY_HTTP_HEAD}->{$first} = $second;
		}
	}
}

######################################################################

=head2 http_body([ VALUE ])

This method is an accessor for the "http body" scalar property of this object,
which it returns.  This contitutes the second of two main parts of
an HTTP response, and contains the actual document that the user will view and/or
can save to disk.  If this property is defined, then it will be used literally as
the HTTP body part of the output.  If this property is not defined then a new
HTTP body of type text/html will be assembled out of the various "page *"
properties instead. This property defaults to undefined.

=cut

######################################################################

sub http_body {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) {
		$self->{$KEY_HTTP_BODY} = $new_value;
	}
	return( $self->{$KEY_HTTP_BODY} );
}

######################################################################

=head2 http_body_is_binary([ VALUE ])

This method is an accessor for the "http body is binary" boolean property of this 
object, which it returns.  If VALUE is defined, this property is set to it.  
If this property is true then it indicates that the HTTP body is binary 
and should be output with binmode on.  It defaults to false.

=cut

######################################################################

sub http_body_is_binary {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) {
		$self->{$KEY_HTTP_BINA} = $new_value;
	}
	return( $self->{$KEY_HTTP_BINA} );
}

######################################################################

=head1 METHODS FOR MAKING NEW HTML PAGES

These methods are designed to accumulate and assemble the components of a new 
HTML page, complete with body, title, meta tags, and cascading style sheets.  
See the DESCRIPTION for more details.

=head2 page_prologue([ VALUE ])

This method is an accessor for the "page prologue" scalar property of this object, 
which it returns.  If VALUE is defined, this property is set to it.  
This property is used as the very first thing in a new HTML page, appearing above 
the opening <HTML> tag.  The property starts out undefined, and unless you set it 
then the default proglogue tag defined by HTML::EasyTags is used instead.  
This property doesn't have any effect unless your HTML::EasyTags is v1-06 or later.

=cut

######################################################################

sub page_prologue {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) {
		$self->{$KEY_PAGE_PROL} = $new_value;
	}
	return( $self->{$KEY_PAGE_PROL} );
}

######################################################################

=head2 page_title([ VALUE ])

This method is an accessor for the "page title" scalar property of this object, 
which it returns.  If VALUE is defined, this property is set to it.  
This property is used in the header of a new HTML document to define its title.  
Specifically, it goes between a <TITLE></TITLE> tag pair.

=cut

######################################################################

sub page_title {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) {
		$self->{$KEY_PAGE_TITL} = $new_value;
	}
	return( $self->{$KEY_PAGE_TITL} );
}

######################################################################

=head2 page_author([ VALUE ])

This method is an accessor for the "page author" scalar property of this object, 
which it returns.  If VALUE is defined, this property is set to it.  
This property is used in the header of a new HTML document to define its author.  
Specifically, it is used in a new '<LINK REV="made">' tag if defined.

=cut

######################################################################

sub page_author {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) {
		$self->{$KEY_PAGE_AUTH} = $new_value;
	}
	return( $self->{$KEY_PAGE_AUTH} );
}

######################################################################

=head2 get_page_meta_ref()

This method is an accessor for the "page meta" hash property of this object, 
a reference to which it returns.  Meta information is used in the header of a
new HTML document to say things like what the best keywords are for a search 
engine to index this page under.  Each key/value pair in the hash would have a 
'<META NAME="k" VALUE="v">' tag made out of it.

=head2 get_page_meta([ KEY ])

This method allows you to get the "page meta" hash property of this object.
If KEY is defined then it is taken as a key in the hash and the associated 
value is returned.  If KEY is not defined then the entire hash is returned as 
a list; in scalar context this list is in a new hash ref.

=head2 set_page_meta( KEY[, VALUE] )

This method allows you to set the "page meta" hash property of this object.
If KEY is a valid HASH ref then all the existing meta information is replaced 
with the new hash keys and values.  If KEY is defined but it is not a Hash ref, 
then KEY and VALUE are inserted together into the existing hash.

=head2 add_page_meta( KEY[, VALUE] )

This method allows you to add key/value pairs to the "page meta" 
hash property of this object.  If KEY is a valid HASH ref then the keys and 
values it contains are inserted into the existing hash property; any like-named 
keys will overwrite existing ones, but different-named ones will coexist.
If KEY is defined but it is not a Hash ref, then KEY and VALUE are inserted 
together into the existing hash.

=cut

######################################################################

sub get_page_meta_ref {
	return( $_[0]->{$KEY_PAGE_META} );  # returns ref for further use
}

sub get_page_meta {
	my ($self, $key) = @_;
	if( defined( $key ) ) {
		return( $self->{$KEY_PAGE_META}->{$key} );
	}
	my %hash_copy = %{$self->{$KEY_PAGE_META}};
	return( wantarray ? %hash_copy : \%hash_copy );
}

sub set_page_meta {
	my ($self, $first, $second) = @_;
	if( defined( $first ) ) {
		if( ref( $first ) eq 'HASH' ) {
			$self->{$KEY_PAGE_META} = {%{$first}};
		} else {
			$self->{$KEY_PAGE_META}->{$first} = $second;
		}
	}
}

sub add_page_meta {
	my ($self, $first, $second) = @_;
	if( defined( $first ) ) {
		if( ref( $first ) eq 'HASH' ) {
			@{$self->{$KEY_PAGE_META}}{keys %{$first}} = values %{$first};
		} else {
			$self->{$KEY_PAGE_META}->{$first} = $second;
		}
	}
}

######################################################################

=head2 get_page_style_sources_ref()

This method is an accessor for the "page style sources" array property of this 
object, a reference to which it returns.  Cascading Style Sheet (CSS) definitions 
are used in the header of a new HTML document to allow precise control over the 
appearance of of page elements, something that HTML itself was not designed for.  
This property stores urls for external documents having stylesheet definitions 
that you want linked to the current document.  If this property is defined, then 
a '<LINK REL="stylesheet" SRC="url">' tag would be made for each list element.

=head2 get_page_style_sources()

This method returns a list containing "page style sources" list elements.  This list 
is returned literally in list context and as an array ref in scalar context.

=head2 set_page_style_sources( VALUE )

This method allows you to set or replace the current "page style sources" 
definitions.  The argument VALUE can be either an array ref or literal list.

=head2 add_page_style_sources( VALUES )

This method will take a list of "page style sources" definitions 
and add them to the internally stored list of the same.  VALUES can be either 
an array ref or a literal list.

=cut

######################################################################

sub get_page_style_sources_ref {
	return( $_[0]->{$KEY_PAGE_CSSR} );  # returns ref for further use
}

sub get_page_style_sources {
	my @array_copy = @{$_[0]->{$KEY_PAGE_CSSR}};
	return( wantarray ? @array_copy : \@array_copy );
}

sub set_page_style_sources {
	my $self = shift( @_ );
	my $ra_values = ref( $_[0] ) eq 'ARRAY' ? $_[0] : \@_;
	@{$self->{$KEY_PAGE_CSSR}} = @{$ra_values};
}

sub add_page_style_sources {
	my $self = shift( @_ );
	my $ra_values = ref( $_[0] ) eq 'ARRAY' ? $_[0] : \@_;
	push( @{$self->{$KEY_PAGE_CSSR}}, @{$ra_values} );
}

######################################################################

=head2 get_page_style_code_ref()

This method is an accessor for the "page style code" array property of this 
object, a reference to which it returns.  Cascading Style Sheet (CSS) definitions 
are used in the header of a new HTML document to allow precise control over the 
appearance of of page elements, something that HTML itself was not designed for.  
This property stores CSS definitions that you want embedded in the HTML document 
itself.  If this property is defined, then a "<STYLE><!-- code --></STYLE>"
multi-line tag is made for them.

=head2 get_page_style_code()

This method returns a list containing "page style code" list elements.  This list 
is returned literally in list context and as an array ref in scalar context.

=head2 set_page_style_code( VALUE )

This method allows you to set or replace the current "page style code" 
definitions.  The argument VALUE can be either an array ref or literal list.

=head2 add_page_style_code( VALUES )

This method will take a list of "page style code" definitions 
and add them to the internally stored list of the same.  VALUES can be either 
an array ref or a literal list.

=cut

######################################################################

sub get_page_style_code_ref {
	return( $_[0]->{$KEY_PAGE_CSSC} );  # returns ref for further use
}

sub get_page_style_code {
	my @array_copy = @{$_[0]->{$KEY_PAGE_CSSC}};
	return( wantarray ? @array_copy : \@array_copy );
}

sub set_page_style_code {
	my $self = shift( @_ );
	my $ra_values = ref( $_[0] ) eq 'ARRAY' ? $_[0] : \@_;
	@{$self->{$KEY_PAGE_CSSC}} = @{$ra_values};
}

sub add_page_style_code {
	my $self = shift( @_ );
	my $ra_values = ref( $_[0] ) eq 'ARRAY' ? $_[0] : \@_;
	push( @{$self->{$KEY_PAGE_CSSC}}, @{$ra_values} );
}

######################################################################

=head2 get_page_head_ref()

This method is an accessor for the "page head" array property of this object, 
a reference to which it returns.  While this property actually represents a 
scalar value, it is stored as an array for possible efficiency, considering that 
new portions may be appended or prepended to it as the program runs.
This property is inserted between the "<HEAD></HEAD>" tags of a new HTML page, 
following any other properties that go in that section.

=head2 get_page_head()

This method returns a string of the "page body" joined together.

=head2 set_page_head( VALUE )

This method allows you to set or replace the current "page head" with a new one.  
The argument VALUE can be either an array ref or scalar or literal list.

=head2 append_page_head( VALUE )

This method allows you to append content to the current "page head".  
The argument VALUE can be either an array ref or scalar or literal list.

=head2 prepend_page_head( VALUE )

This method allows you to prepend content to the current "page head".  
The argument VALUE can be either an array ref or scalar or literal list.

=cut

######################################################################

sub get_page_head_ref {
	return( $_[0]->{$KEY_PAGE_HEAD} );  # returns ref for further use
}

sub get_page_head {
	return( join( '', @{$_[0]->{$KEY_PAGE_HEAD}} ) );
}

sub set_page_head {
	my $self = shift( @_ );
	my $ra_values = ref( $_[0] ) eq 'ARRAY' ? $_[0] : \@_;
	@{$self->{$KEY_PAGE_HEAD}} = @{$ra_values};
}

sub append_page_head {
	my $self = shift( @_ );
	my $ra_values = ref( $_[0] ) eq 'ARRAY' ? $_[0] : \@_;
	push( @{$self->{$KEY_PAGE_HEAD}}, @{$ra_values} );
}

sub prepend_page_head {
	my $self = shift( @_ );
	my $ra_values = ref( $_[0] ) eq 'ARRAY' ? $_[0] : \@_;
	unshift( @{$self->{$KEY_PAGE_HEAD}}, @{$ra_values} );
}

######################################################################

=head2 get_page_frameset_attributes_ref()

This method is an accessor for the "page frameset attributes" hash property of
this object, a reference to which it returns.  Each key/value pair in the hash
would become an attribute key/value of the opening <FRAMESET> tag of a new HTML
document. At least it would if this was a frameset document, which it isn't by
default. If there are multiple frames, then this property says how the browser
window is partitioned into a grid with one or more rows and one or more columns
of frames. Valid attributes include 'rows => "*,*,..."', 'cols => "*,*,..."', and
'border => nn'. See also the http_window_target() method.

=head2 get_page_frameset_attributes([ KEY ])

This method allows you to get the "page frameset attributes" hash property of
this object.  If KEY is defined then it is taken as a key in the hash and the
associated value is returned.  If KEY is not defined then the entire hash is
returned as a list; in scalar context this list is in a new hash ref.

=head2 set_page_frameset_attributes( KEY[, VALUE] )

This method allows you to set the "page frameset attributes" hash property of
this object.  If KEY is a valid HASH ref then all the existing attrib information
is replaced with the new hash keys and values.  If KEY is defined but it is not a
Hash ref, then KEY and VALUE are inserted together into the existing hash.

=head2 add_page_frameset_attributes( KEY[, VALUE] )

This method allows you to add key/value pairs to the "page frameset attributes" 
hash property of this object.  If KEY is a valid HASH ref then the keys and 
values it contains are inserted into the existing hash property; any like-named 
keys will overwrite existing ones, but different-named ones will coexist.
If KEY is defined but it is not a Hash ref, then KEY and VALUE are inserted 
together into the existing hash.

=cut

######################################################################

sub get_page_frameset_attributes_ref {
	return( $_[0]->{$KEY_PAGE_FATR} );  # returns ref for further use
}

sub get_page_frameset_attributes {
	my ($self, $key) = @_;
	if( defined( $key ) ) {
		return( $self->{$KEY_PAGE_FATR}->{$key} );
	}
	my %hash_copy = %{$self->{$KEY_PAGE_FATR}};
	return( wantarray ? %hash_copy : \%hash_copy );
}

sub set_page_frameset_attributes {
	my ($self, $first, $second) = @_;
	if( defined( $first ) ) {
		if( ref( $first ) eq 'HASH' ) {
			$self->{$KEY_PAGE_FATR} = {%{$first}};
		} else {
			$self->{$KEY_PAGE_FATR}->{$first} = $second;
		}
	}
}

sub add_page_frameset_attributes {
	my ($self, $first, $second) = @_;
	if( defined( $first ) ) {
		if( ref( $first ) eq 'HASH' ) {
			@{$self->{$KEY_PAGE_FATR}}{keys %{$first}} = values %{$first};
		} else {
			$self->{$KEY_PAGE_FATR}->{$first} = $second;
		}
	}
}

######################################################################

=head2 get_page_frameset_refs()

This method is an accessor for the "page frameset" array property of this object,
a list of references to whose elements it returns.  Each property element is a
hash ref which contains attributes for a new <FRAME> tag. This property is
inserted between the "<FRAMESET></FRAMESET>" tags of a new HTML page.

=head2 get_page_frameset()

This method returns a list of frame descriptors from the "page frameset"
property.

=head2 set_page_frameset( VALUE )

This method allows you to set or replace the current "page frameset" list with a
new one. The argument VALUE can be either an array ref or scalar or literal list.

=head2 append_page_frameset( VALUE )

This method allows you to append frame descriptors to the current "page frames".
The argument VALUE can be either an array ref or scalar or literal list.

=head2 prepend_page_frameset( VALUE )

This method allows you to prepend frame descriptors to the current "page frames".
The argument VALUE can be either an array ref or scalar or literal list.

=cut

######################################################################

sub get_page_frameset_refs {
	my @values = @{$_[0]->{$KEY_PAGE_FRAM}};
	return( wantarray ? @values : \@values );  # returns ref for further use
}

sub get_page_frameset {
	my @values = map { {%{$_}} } @{$_[0]->{$KEY_PAGE_FRAM}};
	return( wantarray ? @values : \@values );
}

sub set_page_frameset {
	my $self = shift( @_ );
	my $ra_values = ref( $_[0] ) eq 'ARRAY' ? $_[0] : \@_;
	@{$self->{$KEY_PAGE_FRAM}} = grep { ref( $_ ) eq 'HASH' } @{$ra_values};
}

sub append_page_frameset {
	my $self = shift( @_ );
	my $ra_values = ref( $_[0] ) eq 'ARRAY' ? $_[0] : \@_;
	push( @{$self->{$KEY_PAGE_FRAM}}, 
		grep { ref( $_ ) eq 'HASH' } @{$ra_values} );
}

sub prepend_page_frameset {
	my $self = shift( @_ );
	my $ra_values = ref( $_[0] ) eq 'ARRAY' ? $_[0] : \@_;
	unshift( @{$self->{$KEY_PAGE_FRAM}}, 
		grep { ref( $_ ) eq 'HASH' } @{$ra_values} );
}

######################################################################

=head2 get_page_body_attributes_ref()

This method is an accessor for the "page body attributes" hash property of this 
object, a reference to which it returns.  Each key/value pair in the hash would 
become an attribute key/value of the opening <BODY> tag of a new HTML document.
With the advent of CSS there wasn't much need to have the BODY tag attributes, 
but you may wish to do this for older browsers.  In the latter case you could 
use body attributes to define things like the page background color or picture.

=head2 get_page_body_attributes([ KEY ])

This method allows you to get the "page body attributes" hash property of this 
object.  If KEY is defined then it is taken as a key in the hash and the 
associated value is returned.  If KEY is not defined then the entire hash is 
returned as a list; in scalar context this list is in a new hash ref.

=head2 set_page_body_attributes( KEY[, VALUE] )

This method allows you to set the "page body attributes" hash property of this 
object.  If KEY is a valid HASH ref then all the existing attrib information is 
replaced with the new hash keys and values.  If KEY is defined but it is not a 
Hash ref, then KEY and VALUE are inserted together into the existing hash.

=head2 add_page_body_attributes( KEY[, VALUE] )

This method allows you to add key/value pairs to the "page body attributes" 
hash property of this object.  If KEY is a valid HASH ref then the keys and 
values it contains are inserted into the existing hash property; any like-named 
keys will overwrite existing ones, but different-named ones will coexist.
If KEY is defined but it is not a Hash ref, then KEY and VALUE are inserted 
together into the existing hash.

=cut

######################################################################

sub get_page_body_attributes_ref {
	return( $_[0]->{$KEY_PAGE_BATR} );  # returns ref for further use
}

sub get_page_body_attributes {
	my ($self, $key) = @_;
	if( defined( $key ) ) {
		return( $self->{$KEY_PAGE_BATR}->{$key} );
	}
	my %hash_copy = %{$self->{$KEY_PAGE_BATR}};
	return( wantarray ? %hash_copy : \%hash_copy );
}

sub set_page_body_attributes {
	my ($self, $first, $second) = @_;
	if( defined( $first ) ) {
		if( ref( $first ) eq 'HASH' ) {
			$self->{$KEY_PAGE_BATR} = {%{$first}};
		} else {
			$self->{$KEY_PAGE_BATR}->{$first} = $second;
		}
	}
}

sub add_page_body_attributes {
	my ($self, $first, $second) = @_;
	if( defined( $first ) ) {
		if( ref( $first ) eq 'HASH' ) {
			@{$self->{$KEY_PAGE_BATR}}{keys %{$first}} = values %{$first};
		} else {
			$self->{$KEY_PAGE_BATR}->{$first} = $second;
		}
	}
}

######################################################################

=head2 get_page_body_ref()

This method is an accessor for the "page body" array property of this object, 
a reference to which it returns.  While this property actually represents a 
scalar value, it is stored as an array for possible efficiency, considering that 
new portions may be appended or prepended to it as the program runs.
This property is inserted between the "<BODY></BODY>" tags of a new HTML page.

=head2 get_page_body()

This method returns a string of the "page body" joined together.

=head2 set_page_body( VALUE )

This method allows you to set or replace the current "page body" with a new one.  
The argument VALUE can be either an array ref or scalar or literal list.

=head2 append_page_body( VALUE )

This method allows you to append content to the current "page body".  
The argument VALUE can be either an array ref or scalar or literal list.

=head2 prepend_page_body( VALUE )

This method allows you to prepend content to the current "page body".  
The argument VALUE can be either an array ref or scalar or literal list.

=cut

######################################################################

sub get_page_body_ref {
	return( $_[0]->{$KEY_PAGE_BODY} );  # returns ref for further use
}

sub get_page_body {
	return( join( '', @{$_[0]->{$KEY_PAGE_BODY}} ) );
}

sub set_page_body {
	my $self = shift( @_ );
	my $ra_values = ref( $_[0] ) eq 'ARRAY' ? $_[0] : \@_;
	@{$self->{$KEY_PAGE_BODY}} = @{$ra_values};
}

sub append_page_body {
	my $self = shift( @_ );
	my $ra_values = ref( $_[0] ) eq 'ARRAY' ? $_[0] : \@_;
	push( @{$self->{$KEY_PAGE_BODY}}, @{$ra_values} );
}

sub prepend_page_body {
	my $self = shift( @_ );
	my $ra_values = ref( $_[0] ) eq 'ARRAY' ? $_[0] : \@_;
	unshift( @{$self->{$KEY_PAGE_BODY}}, @{$ra_values} );
}

######################################################################

=head2 page_search_and_replace( DO_THIS )

This method performs a customizable search-and-replace of this object's "page *"
properties.  The argument DO_THIS is a hash ref whose keys are tokens to look for
and the corresponding values are what to replace the tokens with.  Tokens can be
any Perl 5 regular expression and they are applied using "s/[find]/[replace]/g". 
Perl will automatically throw an exception if your regular expressions don't
compile, so you should check them for validity before use.  If DO_THIS is not a
valid hash ref then this method returns without changing anything.  Currently,
this method only affects the "page body" property, which is the most common
activity, but in subsequent releases it may process more properties.

=cut

######################################################################

sub page_search_and_replace {
	my ($self, $do_this) = @_;
	ref( $do_this ) eq 'HASH' or return( undef );
	my $body = join( '', @{$self->{$KEY_PAGE_BODY}} );

	foreach my $find_val (keys %{$do_this}) {
		my $replace_val = $do_this->{$find_val};
		$body =~ s/$find_val/$replace_val/g;
	}

	@{$self->{$KEY_PAGE_BODY}} = ($body);
}

######################################################################

=head2 page_as_string()

This method assembles the various "page *" properties of this object into a 
complete HTML page and returns it as a string.  That is, it returns the 
cumulative string representation of those properties.  This consists of a 
prologue tag, a pair of "html" tags, and everything in between.
This method requires HTML::EasyTags to do the actual page assembly, and so the 
results are consistant with its abilities.

=cut

######################################################################

sub page_as_string {
	my $self = shift( @_ );
	my ($title,$author,$meta,$css_src,$css_code,$frameset);

	require HTML::EasyTags;
	my $html = HTML::EasyTags->new();

	# This line is a no-op unless HTML::EasyTags is v1-06 or later.
	$self->{$KEY_PAGE_PROL} and $html->prologue_tag( $self->{$KEY_PAGE_PROL} );

	$self->{$KEY_PAGE_AUTH} and $author = 
		$html->link( rev => 'made', href => "mailto:$self->{$KEY_PAGE_AUTH}" );

	%{$self->{$KEY_PAGE_META}} and $meta = join( '', map { 
		$html->meta_group( name => $_, value => $self->{$KEY_PAGE_META}->{$_} ) 
		} keys %{$self->{$KEY_PAGE_META}} );

	@{$self->{$KEY_PAGE_CSSR}} and $css_src = 
		$html->link_group( rel => 'stylesheet', type => 'text/css', 
		href => $self->{$KEY_PAGE_CSSR} );

	@{$self->{$KEY_PAGE_CSSC}} and $css_code = $html->style( 
		{ type => 'text/css' }, $html->comment_tag( $self->{$KEY_PAGE_CSSC} ) );

	if( %{$self->{$KEY_PAGE_FATR}} or @{$self->{$KEY_PAGE_FRAM}} ) {
		my @frames = map { $html->frame( $_ ) } @{$self->{$KEY_PAGE_FRAM}};
		$frameset = {%{$self->{$KEY_PAGE_FATR}}, text => join( '', @frames )};
	}

	return( join( '', 
		$html->start_html(
			$self->{$KEY_PAGE_TITL},
			[ $author, $meta, $css_src, $css_code, @{$self->{$KEY_PAGE_HEAD}} ], 
			$self->{$KEY_PAGE_BATR}, 
			$frameset,
		), 
		@{$self->{$KEY_PAGE_BODY}},
		$html->end_html( $frameset ),
	) );
}

######################################################################

1;
__END__

=head1 AUTHOR

Copyright (c) 1999-2003, Darren R. Duncan.  All rights reserved.  This module
is free software; you can redistribute it and/or modify it under the same terms
as Perl itself.  However, I do request that this copyright information and
credits remain attached to the file.  If you modify this module and
redistribute a changed version then please attach a note listing the
modifications.  This module is available "as-is" and the author can not be held
accountable for any problems resulting from its use.

I am always interested in knowing how my work helps others, so if you put this
module to use in any of your own products or services then I would appreciate
(but not require) it if you send me the website url for said product or
service, so I know who you are.  Also, if you make non-proprietary changes to
the module because it doesn't work the way you need, and you are willing to
make these freely available, then please send me a copy so that I can roll
desirable changes into the main release.

Address comments, suggestions, and bug reports to B<perl@DarrenDuncan.net>.

=head1 SEE ALSO

perl(1), CGI::Portable, HTML::EasyTags.

=cut

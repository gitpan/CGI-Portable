=head1 NAME

CGI::WPM::Base - Demo of CGI::Portable that is subclassed by 7 other demos.

=cut

######################################################################

package CGI::WPM::Base;
require 5.004;

# Copyright (c) 1999-2001, Darren R. Duncan. All rights reserved. This module is
# free software; you can redistribute it and/or modify it under the same terms as
# Perl itself.  However, I do request that this copyright information remain
# attached to the file.  If you modify this module and redistribute a changed
# version then please attach a note listing the modifications.

use strict;
use vars qw($VERSION);
$VERSION = '0.44';

######################################################################

=head1 DEPENDENCIES

=head2 Perl Version

	5.004

=head2 Standard Modules

	I<none>

=head2 Nonstandard Modules

	CGI::Portable 0.42

=cut

######################################################################

use CGI::Portable 0.42;

######################################################################

=head1 SYNOPSIS

=head2 What are the subclasses of this:

CGI::WPM::GuestBook, CGI::WPM::MailForm, CGI::WPM::MultiPage, CGI::WPM::Redirect, 
CGI::WPM::SegTextDoc, CGI::WPM::Static, and CGI::WPM::Usage.

=head2 How you pass extra Globals-type info to subclasses of this that need it:

	# Note that $globals is an CGI::Portable object.
	# Code like this goes in your startup shell.

	$globals->default_application_title( 'Aardvark On The Range' );
	$globals->default_maintainer_name( 'Tony Simons' );
	$globals->default_maintainer_email_address( 'tony@aardvark.net' );
	$globals->default_maintainer_email_screen_url_path( '/contact/us' );
	$globals->default_smtp_server( 'mail.aardvark.net' );  # defa to 'localhost'
	$globals->default_smtp_timeout( 30 );  # that's also the default

	# And below that you can call_component() on subclasses.
	# The above global-type settings complement the "preferences" below and 
	# in the subclasses, but for these mods they don't live in the preferences.

=head1 DESCRIPTION

This Perl 5 object class is part of a demonstration of CGI::Portable in use.  
It is one of a set of "application components" that takes its settings and user 
input through CGI::Portable and uses that class to send its user output.  
This demo module set can be used together to implement a web site complete with 
static html pages, e-mail forms, guest books, segmented text document display, 
usage tracking, and url-forwarding.  Of course, true to the intent of 
CGI::Portable, each of the modules in this demo set can be used independantly 
of the others.

=head1 SYNTAX

This class does not export any functions or methods, so you need to call them
using object notation.  This means using B<Class-E<gt>function()> for functions
and B<$object-E<gt>method()> for methods.  If you are inheriting this class for
your own modules, then that often means something like B<$self-E<gt>method()>. 

=head1 PUBLIC FUNCTIONS AND METHODS

=head2 main( GLOBALS )

You invoke this method to run the application component that is encapsulated by 
this class.  The required argument GLOBALS is an CGI::Portable object that 
you have previously configured to hold the instance settings and user input for 
this class.  When this method returns then the encapsulated application will 
have finished and you can get its user output from the CGI::Portable object.

=head1 PREFERENCES HANDLED BY THIS MODULE

I<This POD is coming when I get the time to write it.>

All of the properties below can be used with any subclass of Base, but are not 
mentioned separately in any of those modules.

Most of the preferences below correspond directly to CGI::Portable output
properties.  Any properties that are already defined by the subclass of this 
class have higher precedence and if they are set then the properties below are 
not applied; these properties are applied if the subclass does not set them.  

page_body, on the other hand, has high precedence.  If it is set then the 
subclass is never called at all; useful for when you want static html content 
that is defined in your preferences.

page_header and page_footer and page_replace are always used since they don't 
replace the existing html body but add to it or search and replace in it.

amend_msg doesn't apply to any of the above rules.

	amend_msg  # personalized html appears on error page instead of default msg

	http_target   # window target that our output goes in

	page_body    # if defined, no subclass is used and this literal used instead

	page_header  # content goes above our subclass's
	page_footer  # content goes below our subclass's
	page_title   # title for this document
	page_author  # author for this document
	page_meta    # meta tags for this document
	page_css_src   # stylesheet urls to link in
	page_css_code  # css code to embed in head
	page_body_attr # params to put in <BODY>
	page_replace   # search and replacements to perform

=head1 METHOD TO OVERRIDE BY SUBCLASSES

	main_dispatch() -- their version of main(), which is handled in Base

=head1 PRIVATE METHODS FOR USE BY SUBCLASSES

I<This POD is coming when I get the time to write it.>

	get_amendment_message()

=cut

######################################################################

# Names of properties for objects of this class are declared here:
my $KEY_SITE_GLOBALS = 'site_globals';  # hold global site values

# Keys for items in site page preferences:
my $PKEY_AMEND_MSG = 'amend_msg';  # personalized html appears on error page

my $PKEY_HTTP_TARGET = 'http_target';  # window target that our output goes in

my $PKEY_PAGE_BODY = 'page_body';  # if defined, use literally *as* content

my $PKEY_PAGE_HEADER = 'page_header'; # content goes above our subclass's
my $PKEY_PAGE_FOOTER = 'page_footer'; # content goes below our subclass's
my $PKEY_PAGE_TITLE = 'page_title';  # title for this document
my $PKEY_PAGE_AUTHOR = 'page_author';  # author for this document
my $PKEY_PAGE_META = 'page_meta';  # meta tags for this document
my $PKEY_PAGE_CSS_SRC = 'page_css_src';  # stylesheet urls to link in
my $PKEY_PAGE_CSS_CODE = 'page_css_code';  # css code to embed in head
my $PKEY_PAGE_BODY_ATTR = 'page_body_attr';  # params to put in <BODY>
my $PKEY_PAGE_REPLACE = 'page_replace';  # replacements to perform

######################################################################

sub main {
	my ($class, $globals) = @_;
	my $self = bless( {}, ref($class) || $class );

	UNIVERSAL::isa( $globals, 'CGI::Portable' ) or 
		die "initializer is not a valid CGI::Portable object";

	$self->{$KEY_SITE_GLOBALS} = $globals;

	my $body = $globals->pref( $PKEY_PAGE_BODY );
	if( defined( $body ) ) {
		$globals->set_page_body( $body );
	} else {
		$self->main_dispatch();
	}
	
	my $rh_prefs = $globals->get_prefs_ref();
		# note that we don't see parent prefs here, only current level

	$globals->http_window_target() or $globals->http_window_target( $rh_prefs->{$PKEY_HTTP_TARGET} );

	$globals->prepend_page_body( $rh_prefs->{$PKEY_PAGE_HEADER} );
	$globals->append_page_body( $rh_prefs->{$PKEY_PAGE_FOOTER} );

	$globals->page_title() or $globals->page_title( $rh_prefs->{$PKEY_PAGE_TITLE} );
	$globals->page_author() or $globals->page_author( $rh_prefs->{$PKEY_PAGE_AUTHOR} );
	
	if( ref( my $rh_meta = $rh_prefs->{$PKEY_PAGE_META} ) eq 'HASH' ) {
		@{$globals->get_page_meta_ref()}{keys %{$rh_meta}} = values %{$rh_meta};
	}	

	if( defined( my $css_urls_pref = $rh_prefs->{$PKEY_PAGE_CSS_SRC} ) ) {
		push( @{$globals->get_page_style_sources_ref()}, 
			ref($css_urls_pref) eq 'ARRAY' ? @{$css_urls_pref} : () );
	}
	if( defined( my $css_code_pref = $rh_prefs->{$PKEY_PAGE_CSS_CODE} ) ) {
		push( @{$globals->get_page_style_code_ref()}, 
			ref($css_code_pref) eq 'ARRAY' ? @{$css_code_pref} : () );
	}

	if( ref(my $rh_body = $rh_prefs->{$PKEY_PAGE_BODY_ATTR}) eq 'HASH' ) {
		@{$globals->get_page_body_attributes_ref()}{keys %{$rh_body}} = 
			values %{$rh_body};
	}

	$globals->search_and_replace_page_body( $rh_prefs->{$PKEY_PAGE_REPLACE} );
}

######################################################################

# subclass should have their own of these
sub main_dispatch {
	my $self = shift( @_ );
	my $globals = $self->{$KEY_SITE_GLOBALS};

	$globals->page_title( 'Web Page For Users' );

	$globals->set_page_body( <<__endquote );
<H2 ALIGN="center">@{[$globals->page_title()]}</H2>

<P>This web page has been generated by CGI::WPM::Base, which is 
copyright (c) 1999-2001, Darren R. Duncan.  This Perl Class 
is intended to be subclassed before it is used.</P>

<P>You are reading this message because either no subclass is in use 
or that subclass hasn't declared the main_dispatch() method.</P>
__endquote
}

######################################################################

sub get_amendment_message {
	my ($self) = shift( @_ );
	my $globals = $self->{$KEY_SITE_GLOBALS};
	return( $globals->pref( $PKEY_AMEND_MSG ) || <<__endquote );
<P>This should be temporary, the result of a transient server problem
or a site update being performed at the moment.  Click 
@{[$globals->recall_html('here')]} to automatically try again.  
If the problem persists, please try again later, or send an
@{[$globals->maintainer_email_html('e-mail')]}
message about the problem, so it can be fixed.</P>
__endquote
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

perl(1), CGI::Portable, CGI::WPM::GuestBook, CGI::WPM::MailForm, 
CGI::WPM::MultiPage, CGI::WPM::Redirect, CGI::WPM::SegTextDoc, CGI::WPM::Static, 
and CGI::WPM::Usage, CGI::Portable::AdapterCGI.

=cut

=head1 NAME

CGI::WPM::Static - Demo of CGI::Portable that displays a static HTML page.

=cut

######################################################################

package CGI::WPM::Static;
require 5.004;

# Copyright (c) 1999-2001, Darren R. Duncan. All rights reserved. This module is
# free software; you can redistribute it and/or modify it under the same terms as
# Perl itself.  However, I do request that this copyright information remain
# attached to the file.  If you modify this module and redistribute a changed
# version then please attach a note listing the modifications.

use strict;
use vars qw($VERSION @ISA);
$VERSION = '0.41';

######################################################################

=head1 DEPENDENCIES

=head2 Perl Version

	5.004

=head2 Standard Modules

	I<none>

=head2 Nonstandard Modules

	CGI::Portable 0.41
	CGI::WPM::Base 0.41

=cut

######################################################################

use CGI::Portable 0.41;
use CGI::WPM::Base 0.41;
@ISA = qw(CGI::WPM::Base);

######################################################################

=head1 SYNOPSIS

=head2 Display An HTML File

	#!/usr/bin/perl
	use strict;

	require CGI::Portable;
	my $globals = CGI::Portable->new();

	use Cwd;
	$globals->file_path_root( cwd() );  # let us default to current working dir
	$globals->file_path_delimiter( $^O=~/Mac/i ? ":" : $^O=~/Win/i ? "\\" : "/" );

	my %CONFIG = ( filename => 'intro.html' );

	$globals->set_prefs( \%CONFIG );
	$globals->call_component( 'CGI::WPM::Static' );

	require CGI::WPM::SimpleUserIO;
	my $io = CGI::WPM::SimpleUserIO->new();
	$io->send_user_output_from_cgi_portable( $globals );

	1;

=head2 Display A Plain Text File -- HTML Escaped

	my %CONFIG = ( filename => 'mycode.txt', is_text => 1 );

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

	filename  # name of file we will open
	is_text   # true if file is not html, but text

=cut

######################################################################

# Names of properties for objects of parent class are declared here:
my $KEY_SITE_GLOBALS = 'site_globals';  # hold global site values

# Keys for items in site page preferences:
my $PKEY_FILENAME = 'filename';  # name of file we will open
my $PKEY_IS_TEXT  = 'is_text';   # true if file is not html, but text

######################################################################
# This is provided so CGI::WPM::Base->main() can call it.

sub main_dispatch {
	my $self = shift( @_ );
	my $globals = $self->{$KEY_SITE_GLOBALS};
	my $filename = $globals->pref( $PKEY_FILENAME );
	my $physical_path = $globals->physical_filename( $filename );
	my $is_text = $globals->pref( $PKEY_IS_TEXT );

	SWITCH: {
		$globals->add_no_error();

		open( STATIC, "<$physical_path" ) or do {
			$globals->add_virtual_filename_error( "open", $filename );
			last SWITCH;
		};
		local $/ = undef;
		defined( my $file_content = <STATIC> ) or do {
			$globals->add_virtual_filename_error( "read from", $filename );
			last SWITCH;
		};
		close( STATIC ) or do {
			$globals->add_virtual_filename_error( "close", $filename );
			last SWITCH;
		};
		
		if( $is_text ) {
			$file_content =~ s/&/&amp;/g;  # do some html escaping
			$file_content =~ s/\"/&quot;/g;
			$file_content =~ s/>/&gt;/g;
			$file_content =~ s/</&lt;/g;
		
			$globals->set_page_body( 
				[ "\n<PRE>\n", $file_content, "\n</PRE>\n" ] );
		
		} elsif( $file_content =~ m|<BODY[^>]*>(.*)</BODY>|si ) {
			$globals->set_page_body( $1 );
			if( $file_content =~ m|<TITLE>(.*)</TITLE>|si ) {
				$globals->page_title( $1 );
			}
		} else {
			$globals->set_page_body( $file_content );
		}	
	}

	if( $globals->get_error() ) {
		$globals->page_title( 'Error Opening Page' );
		$globals->set_page_body( <<__endquote );
<H2 ALIGN="center">@{[$globals->page_title()]}</H2>

<P>I'm sorry, but an error has occurred while trying to open 
the page you requested, which is in the file "$filename".</P>  

@{[$self->_get_amendment_message()]}

<P>Details: @{[$globals->get_error()]}</P>
__endquote

		$globals->add_no_error();
	}
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

perl(1), CGI::Portable, CGI::WPM::Base, CGI::WPM::SimpleUserIO.

=cut

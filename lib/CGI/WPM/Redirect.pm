=head1 NAME

CGI::WPM::Redirect - Demo of CGI::Portable sending a redirection header.

=cut

######################################################################

package CGI::WPM::Redirect;
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

=head2 Redirect To A Custom Url In User Query Parameter 'url'

	#!/usr/bin/perl
	use strict;

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

=head2 Always Redirect To Same Url

	my %CONFIG = ( url => 'http://www.cpan.org' );

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

	url  # preferences can say where we redirect to

=cut

######################################################################

# Names of properties for objects of parent class are declared here:
my $KEY_SITE_GLOBALS = 'site_globals';  # hold global site values

# Keys for items in site page preferences:
my $PKEY_EXPL_DEST_URL = 'url';  # our preferences may tell us where

# Constant values used by this class:
my $UIPN_DEST_URL = 'url';  # or look in the user query instead

######################################################################
# This is provided so CGI::WPM::Base->main() can call it.

sub main_dispatch {
	my $self = shift( @_ );
	my $globals = $self->{$KEY_SITE_GLOBALS};
	my $dest_url = $globals->pref( $PKEY_EXPL_DEST_URL ) || 
		$globals->user_query_param( $UIPN_DEST_URL );
	
	unless( $dest_url ) {
		$globals->page_title( 'No Url Provided' );

		$globals->set_page_body( <<__endquote );
<H2 ALIGN="center">@{[$globals->page_title()]}</H2>

<P>I'm sorry, but this redirection page requires either a site 
preference named "$PKEY_EXPL_DEST_URL", or a query parameter named 
"$UIPN_DEST_URL", whose value is an url.  No url was provided, so I 
can't redirect you to it.  If you got this error while clicking 
on one of the links on this website, then the problem is likely 
on this end.  In the latter case...</P>

@{[$self->_get_amendment_message()]}
__endquote

		return( 1 );
	}

	$globals->http_status_code( '301 Moved' );
	$globals->http_redirect_url( $dest_url );
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

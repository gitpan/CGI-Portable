=head1 NAME

CGI::WPM::SegTextDoc - Demo of CGI::Portable that displays a static text 
page, which can be in multiple segments.

=cut

######################################################################

package CGI::WPM::SegTextDoc;
require 5.004;

# Copyright (c) 1999-2001, Darren R. Duncan. All rights reserved. This module is
# free software; you can redistribute it and/or modify it under the same terms as
# Perl itself.  However, I do request that this copyright information remain
# attached to the file.  If you modify this module and redistribute a changed
# version then please attach a note listing the modifications.

use strict;
use vars qw($VERSION @ISA);
$VERSION = '0.44';

######################################################################

=head1 DEPENDENCIES

=head2 Perl Version

	5.004

=head2 Standard Modules

	I<none>

=head2 Nonstandard Modules

	CGI::Portable 0.41
	CGI::WPM::Base 0.44
	CGI::WPM::Static 0.41

=cut

######################################################################

use CGI::Portable 0.41;
use CGI::WPM::Base 0.44;
@ISA = qw(CGI::WPM::Base);

######################################################################

=head1 SYNOPSIS

=head2 Display A Text File In Multiple Segments

	#!/usr/bin/perl
	use strict;

	require CGI::Portable;
	my $globals = CGI::Portable->new();

	use Cwd;
	$globals->file_path_root( cwd() );  # let us default to current working dir
	$globals->file_path_delimiter( $^O=~/Mac/i ? ":" : $^O=~/Win/i ? "\\" : "/" );

	require CGI::Portable::AdapterCGI;
	my $io = CGI::Portable::AdapterCGI->new();
	$io->fetch_user_input( $globals );

	my %CONFIG = (
		title => 'Index of the World',
		author => 'Jules Verne',
		created => 'Version 1.0, first created 1993 June 24',
		updated => 'Version 3.1, last modified 2000 November 18',
		filename => 'jv_world.txt',
		segments => 24,
	);

	$globals->current_user_path_level( 1 );
	$globals->set_prefs( \%CONFIG );
	$globals->call_component( 'CGI::WPM::SegTextDoc' );

	$io->send_user_output( $globals );

	1;

I<You need to have a subdirectory named "jv_world" that contains the 24 files 
that correspond to the segments, named "jv_world_001.txt" through "...024.txt".>

=head2 Display A Text File All On One Page

	my %CONFIG = (
		title => 'Pizza Joints In New York',
		author => 'Oscar Wilder',
		created => 'Version 0.5, first created 1997 February 17',
		updated => 'Version 1.2, last modified 1998 March 8',
		filename => 'ow_pizza.txt',
		segments => 1,  # also the default
	);

I<You need to have a single file named "ow_pizza.txt", not in a subdirectory.>

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

	title    # title of the document
	author   # who made the document
	created  # date and number of first version
	updated  # date and number of newest version
	filename # common part of filename for pieces
	segments # number of pieces doc is in

=cut

######################################################################

# Names of properties for objects of this class are declared here:
my $KEY_SITE_GLOBALS = 'site_globals';  # hold global site values

# Keys for items in site page preferences:
my $PKEY_TITLE = 'title';        # title of the document
my $PKEY_AUTHOR = 'author';      # who made the document
my $PKEY_CREATED = 'created';    # date and number of first version
my $PKEY_UPDATED = 'updated';    # date and number of newest version
my $PKEY_FILENAME = 'filename';  # common part of filename for pieces
my $PKEY_SEGMENTS = 'segments';  # number of pieces doc is in

######################################################################
# This is provided so CGI::WPM::Base->main() can call it.

sub main_dispatch {
	my $self = shift( @_ );
	my $globals = $self->{$KEY_SITE_GLOBALS};
	my $rh_prefs = $globals->get_prefs_ref();
	
	my $segments = $rh_prefs->{$PKEY_SEGMENTS};
	$segments >= 1 or $rh_prefs->{$PKEY_SEGMENTS} = $segments = 1;

	my $curr_seg_num = $globals->current_user_path_element();
	$curr_seg_num >= 1 or $curr_seg_num = 1;
	$curr_seg_num <= $segments or $curr_seg_num = $segments;
	$globals->current_user_path_element( $curr_seg_num );
	
	$self->get_curr_seg_content();
	if( $segments > 1 ) {
		$self->attach_document_navbar();
	}
	$self->attach_document_header();
}

######################################################################

sub get_curr_seg_content {
	my $self = shift( @_ );
	my $globals = $self->{$KEY_SITE_GLOBALS};
	my $rh_prefs = $globals->get_prefs_ref();
	my $is_multi_segmented = $rh_prefs->{$PKEY_SEGMENTS} > 1;

	my ($base, $ext) = ($rh_prefs->{$PKEY_FILENAME} =~ m/^([^\.]*)(.*)$/);
	my $seg_num_str = $is_multi_segmented ?
		'_'.sprintf( "%3.3d", $globals->current_user_path_element() ) : '';

	my $wpm_prefs = {
		filename => "$base$seg_num_str$ext",
		is_text => 1,
	};
	
	my $wpm_context = $globals->make_new_context();
	$is_multi_segmented and $wpm_context->navigate_file_path( $base );
	$wpm_context->set_prefs( $wpm_prefs );
	$wpm_context->call_component( 'CGI::WPM::Static' );
	$globals->take_context_output( $wpm_context );
}

######################################################################

sub attach_document_navbar {
	my $self = shift( @_ );
	my $globals = $self->{$KEY_SITE_GLOBALS};

	my $segments = $globals->get_prefs_ref()->{$PKEY_SEGMENTS};
	my $curr_seg_num = $globals->current_user_path_element();
	my $seg_token = '__std_seg_token__';
	my $common_url = $globals->url_as_string( $seg_token );

	my @seg_list_html = ();
	foreach my $seg_num (1..$segments) {
		if( $seg_num == $curr_seg_num ) {
			push( @seg_list_html, "$seg_num\n" );
		} else {
			my $curr_seg_html = "<A HREF=\"$common_url\">$seg_num</A>\n";
			$curr_seg_html =~ s/$seg_token/$seg_num/g;
			push( @seg_list_html, $curr_seg_html );
		}
	}
	
	my $prev_seg_html = ($curr_seg_num == 1) ? "Previous\n" :
		"<A HREF=\"$common_url\">Previous</A>\n";
	$prev_seg_html =~ s/$seg_token/$curr_seg_num-1/ge;
	
	my $next_seg_html = ($curr_seg_num == $segments) ? "Next\n" :
		"<A HREF=\"$common_url\">Next</A>\n";
	$next_seg_html =~ s/$seg_token/$curr_seg_num+1/ge;
	
	my $document_navbar =
		<<__endquote.
<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=10><TR>
 <TD>$prev_seg_html</TD><TD ALIGN="center">
__endquote

		join( ' | ', @seg_list_html ).

		<<__endquote;
 </TD><TD>$next_seg_html</TD>
</TR></TABLE>
__endquote

	$globals->prepend_page_body( [$document_navbar] );
	$globals->append_page_body( [$document_navbar] );
}

######################################################################

sub attach_document_header {
	my $self = shift( @_ );
	my $globals = $self->{$KEY_SITE_GLOBALS};
	my $rh_prefs = $globals->get_prefs_ref();

	my $title = $rh_prefs->{$PKEY_TITLE};
	my $author = $rh_prefs->{$PKEY_AUTHOR};
	my $created = $rh_prefs->{$PKEY_CREATED};
	my $updated = $rh_prefs->{$PKEY_UPDATED};
	my $segments = $rh_prefs->{$PKEY_SEGMENTS};
	
	my $curr_seg_num = $globals->current_user_path_element();
	$title .= $segments > 1 ? ": $curr_seg_num / $segments" : '';
	
	$globals->page_title( $title );

	$globals->prepend_page_body( <<__endquote );
<H2>@{[$globals->page_title()]}</H2>

<P>Author: $author<BR>
Created: $created<BR>
Updated: $updated</P>
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

perl(1), CGI::Portable, CGI::WPM::Base, CGI::WPM::Static, CGI::Portable::AdapterCGI.

=cut

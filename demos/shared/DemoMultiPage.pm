=head1 NAME

DemoMultiPage - Demo of CGI::Portable that resolves navigation for one 
level in the web site page hierarchy from a parent node to its children, 
encapsulates and returns its childrens' returned web page components, and can 
make a navigation bar to child pages.

=cut

######################################################################

package DemoMultiPage;
require 5.004;

# Copyright (c) 1999-2001, Darren R. Duncan. All rights reserved. This module is
# free software; you can redistribute it and/or modify it under the same terms as
# Perl itself.  However, I do request that this copyright information remain
# attached to the file.  If you modify this module and redistribute a changed
# version then please attach a note listing the modifications.

use strict;
use vars qw($VERSION @ISA);
$VERSION = '0.45';

######################################################################

=head1 DEPENDENCIES

=head2 Perl Version

	5.004

=head2 Standard Modules

	I<none>

=head2 Nonstandard Modules

	CGI::Portable 0.45
	CGI::Portable::AppStatic 0.45

=cut

######################################################################

use CGI::Portable 0.45;
use CGI::Portable::AppStatic 0.45;
@ISA = qw(CGI::Portable::AppStatic);

######################################################################

=head1 SYNOPSIS

=head2 A multiple page website with static html, mail, gb, redir, usage tracking

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

	if( $globals->user_query_param( 'debugging' ) eq 'on' ) {
		$globals->is_debug( 1 );
		$globals->url_query_param( 'debugging', 'on' );
	}
	
	$globals->default_application_title( 'Demo Web Site' );
	$globals->default_maintainer_name( 'Tony Simons' );
	$globals->default_maintainer_email_address( 'tony@aardvark.net' );
	$globals->default_maintainer_email_screen_url_path( '/mailme' );

	my $content = $globals->make_new_context();
	$content->current_user_path_level( 1 );
	$content->navigate_file_path( 'content' );
	$content->set_prefs( 'content_prefs.pl' );
	$content->call_component( 'DemoMultiPage' );
	$globals->take_context_output( $content );

	my $usage = $globals->make_new_context();
	$usage->http_redirect_url( $globals->http_redirect_url() );
	$usage->navigate_file_path( $globals->is_debug() ? 'usage_debug' : 'usage' );
	$usage->set_prefs( '../usage_prefs.pl' );
	$usage->call_component( 'DemoUsage' );
	$globals->take_context_output( $usage, 1, 1 );

	if( $globals->is_debug() ) {
		$globals->append_page_body( <<__endquote );
<P>Debugging is currently turned on.</P>
__endquote
	}

	$globals->search_and_replace_page_body( { 
		__mailme_url__ => "__url_path__=/mailme",
		__external_id__ => "__url_path__=/external&url",
	} );
	$globals->search_and_replace_url_path_tokens( '__url_path__' );

	$io->send_user_output( $globals );

	1;

=head2 Content of settings file "content_prefs.pl"

	my $rh_preferences = { 
		prepend_page_body => <<__endquote,
	__endquote
		append_page_body => <<__endquote,
	<P><EM>Demo Web Site was created and is maintained for personal use by 
	<A HREF="__mailme_url__">Tony Simons</A>.  All content and source code was 
	created by me, unless otherwise stated.  Content that I did not create is 
	used with permission from the creators, who are appropriately credited where 
	it is used and in the Works Cited section of this site.</EM></P>
	__endquote
		add_page_style_code => [
			'BODY {background-color: white; background-image: none}'
		],
		page_replace => {
			__graphics_directories__ => 'http://www.aardvark.net/graphics_directories',
			__graphics_webring__ => 'http://www.aardvark.net/graphics_webring',
		},
		vrp_handlers => {
			external => {
				wpm_module => 'DemoRedirect',
				wpm_prefs => { low_http_window_target => 'external_link_window' },
			},
			frontdoor => {
				wpm_module => 'DemoStatic',
				wpm_prefs => { filename => 'frontdoor.html' },
			},
			intro => {
				wpm_module => 'DemoStatic',
				wpm_prefs => { filename => 'intro.html' },
			},
			whatsnew => {
				wpm_module => 'DemoStatic',
				wpm_prefs => { filename => 'whatsnew.html' },
			},
			timelines => {
				wpm_module => 'DemoStatic',
				wpm_prefs => { filename => 'timelines.html' },
			},
			indexes => {
				wpm_module => 'DemoStatic',
				wpm_prefs => { filename => 'indexes.html' },
			},
			cited => {
				wpm_module => 'DemoMultiPage',
				wpm_subdir => 'cited',
				wpm_prefs => 'cited_prefs.pl',
			},
			mailme => {
				wpm_module => 'DemoMailForm',
				wpm_prefs => {},
			},
			guestbook => {
				wpm_module => 'DemoGuestBook',
				wpm_prefs => {
					custom_fd => 1,
					field_defn => 'guestbook_questions.txt',
					fd_in_seqf => 1,
					fn_messages => 'guestbook_messages.txt',
				},
			},
			links => {
				wpm_module => 'DemoStatic',
				wpm_prefs => { filename => 'links.html' },
			},
			webrings => {
				wpm_module => 'DemoStatic',
				wpm_prefs => { filename => 'webrings.html' },
			},
		},
		def_handler => 'frontdoor',
		menu_items => [
			{
				menu_name => 'Front Door',
				menu_path => '',
				is_active => 1,
			}, {
				menu_name => 'Welcome to DemoWeb',
				menu_path => 'intro',
				is_active => 1,
			}, {
				menu_name => "What's New",
				menu_path => 'whatsnew',
				is_active => 1,
			}, 1, {
				menu_name => 'Story Timelines',
				menu_path => 'timelines',
				is_active => 1,
			}, {
				menu_name => 'Issue Indexes',
				menu_path => 'indexes',
				is_active => 1,
			}, {
				menu_name => 'Works Cited',
				menu_path => 'cited',
				is_active => 1,
			}, {
				menu_name => 'Preview Database',
				menu_path => 'dbprev',
				is_active => 0,
			}, 1, {
				menu_name => 'Send Me E-mail',
				menu_path => 'mailme',
				is_active => 1,
			}, {
				menu_name => 'Guest Book',
				menu_path => 'guestbook',
				is_active => 1,
			}, 1, {
				menu_name => 'External Links',
				menu_path => 'links',
				is_active => 1,
			}, {
				menu_name => 'Webrings',
				menu_path => 'webrings',
				is_active => 1,
			},
		],
		menu_cols => 4,
	#	menu_colwid => 100,
		menu_showdiv => 0,
	#	menu_bgcolor => '#ddeeff',
		page_showdiv => 1,
	};

=head2 Content of settings file "usage_prefs.pl"

I<Please see the POD for DemoUsage for this file; that Synopsis POD is 
being made in conjunction with the POD for DemoMultiPage.>

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

	vrp_handlers  # match wpm handler to a vrp
	def_handler   # if vrp undef, which handler?
	menu_items    # items in site menu, vrp for each
	menu_cols     # menu divided into n cols
	menu_colwid   # width of each col, in pixels
	menu_showdiv  # show dividers btwn menu groups?
	menu_bgcolor  # background for menu
	menu_showdiv  # show dividers btwn menu groups?
	page_showdiv  # do we use HRs to sep menu?

=head2 PROPERTIES OF ELEMENTS IN vrp_handlers HASH

	wpm_module  # wpm module making content
	wpm_subdir  # subdir holding wpm support files
	wpm_prefs   # prefs hash/fn we give to wpm mod

=head2 PROPERTIES OF ELEMENTS IN menu_items ARRAY

	menu_name  # visible name appearing in site menu
	menu_path  # vrp used in url for menu item
	is_active  # is menu item enabled or not?

=cut

######################################################################

# Names of properties for objects of this class are declared here:
my $KEY_SITE_GLOBALS = 'site_globals';  # hold global site values

# Keys for items in site page preferences:
my $PKEY_VRP_HANDLERS = 'vrp_handlers';  # match wpm handler to a vrp
my $PKEY_DEF_HANDLER  = 'def_handler';  # if vrp undef, which handler?
my $PKEY_MENU_ITEMS   = 'menu_items';  # items in site menu, vrp for each
my $PKEY_MENU_COLS    = 'menu_cols';  # menu divided into n cols
my $PKEY_MENU_COLWID  = 'menu_colwid';  # width of each col, in pixels
my $PKEY_MENU_SHOWDIV = 'menu_showdiv';  # show dividers btwn menu groups?
my $PKEY_MENU_BGCOLOR = 'menu_bgcolor';  # background for menu
my $PKEY_PAGE_SHOWDIV = 'page_showdiv';  # do we use HRs to sep menu?

# Keys for elements in $PKEY_VRP_HANDLERS hash:
my $HKEY_WPM_MODULE = 'wpm_module';  # wpm module making content
my $HKEY_WPM_SUBDIR = 'wpm_subdir';  # subdir holding wpm support files
my $HKEY_WPM_PREFS = 'wpm_prefs';  # prefs hash/fn we give to wpm mod

# Keys for elements in $PKEY_MENU_ITEMS array:
my $MKEY_MENU_NAME = 'menu_name';  # visible name appearing in site menu
my $MKEY_MENU_PATH = 'menu_path';  # vrp used in url for menu item
my $MKEY_IS_ACTIVE = 'is_active';  # is menu item enabled or not?

######################################################################

sub main {
	my ($class, $globals) = @_;
	my $self = bless( {}, ref($class) || $class );

	UNIVERSAL::isa( $globals, 'CGI::Portable' ) or 
		die "initializer is not a valid CGI::Portable object";

	$self->set_static_low_replace( $globals );

	$self->{$KEY_SITE_GLOBALS} = $globals;
	$self->main_dispatch();

	$self->set_static_high_replace( $globals );
	$self->set_static_attach_unordered( $globals );
	$self->set_static_attach_ordered( $globals );
	$self->set_static_miscellaneous( $globals );
}

######################################################################

sub main_dispatch {
	my $self = shift( @_ );

	$self->get_inner_wpm_content();  # puts in webpage of $globals

	my $globals = $self->{$KEY_SITE_GLOBALS};
	my $rh_prefs = $globals->get_prefs_ref();

	if( $rh_prefs->{$PKEY_PAGE_SHOWDIV} ) {
		$globals->prepend_page_body( "\n<HR>\n" );
		$globals->append_page_body( "\n<HR>\n" );
	}

	if( ref( $rh_prefs->{$PKEY_MENU_ITEMS} ) eq 'ARRAY' ) {
		$self->attach_page_menu();
	}
}

######################################################################

sub get_inner_wpm_content {
	my $self = shift( @_ );
	my $globals = $self->{$KEY_SITE_GLOBALS};
	my $rh_prefs = $globals->get_prefs_ref();

	my $page_id = $globals->current_user_path_element();
	$page_id ||= $rh_prefs->{$PKEY_DEF_HANDLER};
	my $vrp_handler = $rh_prefs->{$PKEY_VRP_HANDLERS}->{$page_id};
	
	unless( ref( $vrp_handler ) eq 'HASH' ) {
		$globals->page_title( '404 Page Not Found' );

		$globals->set_page_body( <<__endquote );
<H1>@{[$globals->page_title()]}</H1>

<P>I'm sorry, but the page you requested, 
"@{[$globals->user_path_string()]}", doesn't seem to exist.  
If you manually typed that address into the browser, then it is either 
outdated or you misspelled it.  If you got this error while clicking 
on one of the links on this website, then the problem is likely 
on this end.  In the latter case...</P>

@{[$self->get_amendment_message()]}
__endquote

		return( 1 );
	}
	
	my $wpm_context = $globals->make_new_context();
	$wpm_context->inc_user_path_level();
	$wpm_context->navigate_url_path( $page_id );
	$wpm_context->navigate_file_path( $vrp_handler->{$HKEY_WPM_SUBDIR} );
	$wpm_context->set_prefs( $vrp_handler->{$HKEY_WPM_PREFS} );
	$wpm_context->call_component( $vrp_handler->{$HKEY_WPM_MODULE} );
	$globals->take_context_output( $wpm_context );
}

######################################################################

sub attach_page_menu {
	my $self = shift( @_ );
	my $globals = $self->{$KEY_SITE_GLOBALS};
	
	my $menu_table = $self->make_page_menu_table();

	$globals->prepend_page_body( [$menu_table] );
	$globals->append_page_body( [$menu_table] );
}

######################################################################

sub make_menu_items_html {
	my $self = shift( @_ );
	my $globals = $self->{$KEY_SITE_GLOBALS};	
	my $rh_prefs = $globals->get_prefs_ref();
	my $ra_menu_items = $rh_prefs->{$PKEY_MENU_ITEMS};
	my @menu_html = ();
	
	foreach my $rh_curr_page (@{$ra_menu_items}) {
		if( ref( $rh_curr_page ) ne 'HASH' ) {
			$rh_prefs->{$PKEY_MENU_SHOWDIV} or next;
			push( @menu_html, undef );   # insert menu divider,
			next;                   
		}

		unless( $rh_curr_page->{$MKEY_IS_ACTIVE} ) {
			push( @menu_html, "$rh_curr_page->{$MKEY_MENU_NAME}" );
			next;
		}
		
		my $url = $globals->url_as_string( 
			$rh_curr_page->{$MKEY_MENU_PATH} );
		push( @menu_html, "<A HREF=\"$url\"".
			">$rh_curr_page->{$MKEY_MENU_NAME}</A>" );
	}
	
	return( @menu_html );
}

######################################################################
# This method currently isn't called by anything, but may be later.

sub make_page_menu_vert {
	my $self = shift( @_ );
	my @menu_items = $self->make_menu_items_html();
	my @menu_html = ();
	my $prev_item = undef;
	foreach my $curr_item (@menu_items) {
		push( @menu_html, 
			!defined( $curr_item ) ? "<HR>\n" : 
			defined( $prev_item ) ? "<BR>$curr_item\n" : 
			"$curr_item\n" );
		$prev_item = $curr_item;
	}
	return( '<P>'.join( '', @menu_html ).'</P>' );
}

######################################################################
# This method currently isn't called by anything, but may be later.

sub make_page_menu_horiz {
	my $self = shift( @_ );
	my @menu_items = $self->make_menu_items_html();
	my @menu_html = ();
	foreach my $curr_item (@menu_items) {
		defined( $curr_item ) or next;
		push( @menu_html, "$curr_item\n" );
	}
	return( '<P>'.join( ' | ', @menu_html ).'</P>' );
}

######################################################################

sub make_page_menu_table {
	my $self = shift( @_ );
	my $rh_prefs = $self->{$KEY_SITE_GLOBALS}->get_prefs_ref();
	my @menu_items = $self->make_menu_items_html();
	
	my $length = scalar( @menu_items );
	my $max_cols = $rh_prefs->{$PKEY_MENU_COLS};
	$max_cols <= 1 and $max_cols = 1;
	my $max_rows = 
		int( $length / $max_cols ) + ($length % $max_cols ? 1 : 0);

	my $colwid = $rh_prefs->{$PKEY_MENU_COLWID};
	$colwid and $colwid = " WIDTH=\"$colwid\"";
	
	my $bgcolor = $rh_prefs->{$PKEY_MENU_BGCOLOR};
	$bgcolor and $bgcolor = " BGCOLOR=\"$bgcolor\"";
	
	my @table_lines = ();
	
	push( @table_lines, "<TABLE BORDER=0 CELLSPACING=0 ".
		"CELLPADDING=10 ALIGN=\"center\">\n<TR>\n" );
	
	foreach my $col_num (1..$max_cols) {
		my $prev_item = undef;
		my @cell_lines = ();
		my @cell_items = splice( @menu_items, 0, $max_rows ) or last;
		foreach my $curr_item (@cell_items) {
			push( @cell_lines, 
				!defined( $curr_item ) ? "<HR>\n" : 
				defined( $prev_item ) ? "<BR>$curr_item\n" : 
				"$curr_item\n" );
			$prev_item = $curr_item;
		}
		push( @table_lines,
			"<TD ALIGN=\"left\" VALIGN=\"top\"$bgcolor$colwid>\n",
			@cell_lines, "</TD>\n" );
	}
	
	push( @table_lines, "</TR>\n</TABLE>\n" );

	return( join( '', @table_lines ) );
}

######################################################################

sub get_amendment_message {
	my ($self) = shift( @_ );
	my $globals = $self->{$KEY_SITE_GLOBALS};
	return( <<__endquote );
<P>This should be temporary, the result of a transient server problem or an 
update being performed at the moment.  Click @{[$globals->recall_html('here')]} 
to automatically try again.  If the problem persists, please try again later, 
or send an @{[$globals->maintainer_email_html('e-mail')]} message about the 
problem, so it can be fixed.</P>
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

perl(1), CGI::Portable, CGI::Portable::AppStatic, CGI::Portable::AdapterCGI.

=cut

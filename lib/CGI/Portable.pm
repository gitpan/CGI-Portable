=head1 NAME

CGI::Portable - Framework for server-agnostic web apps.

=cut

######################################################################

package CGI::Portable;
require 5.004;

# Copyright (c) 1999-2001, Darren R. Duncan. All rights reserved. This module is
# free software; you can redistribute it and/or modify it under the same terms as
# Perl itself.  However, I do request that this copyright information remain
# attached to the file.  If you modify this module and redistribute a changed
# version then please attach a note listing the modifications.

use strict;
use vars qw($VERSION);
$VERSION = '0.41';

######################################################################

=head1 DEPENDENCIES

=head2 Perl Version

	5.004

=head2 Standard Modules

	I<none>

=head2 Nonstandard Modules

	File::VirtualPath 1.0
	HTML::EasyTags 1.04
	Data::MultiValuedHash 1.07
	CGI::MultiValuedHash 1.07

=cut

######################################################################

use File::VirtualPath 1.0;
use HTML::EasyTags 1.04;
use Data::MultiValuedHash 1.07;
use CGI::MultiValuedHash 1.07;

######################################################################

=head1 SYNOPSIS

=head2 Content of thin shell "startup_manual.pl" for CGI environment:

I<See also the CGI::WPM::SimpleUserIO module, whose Synopsis contains a version 
of startup_manual.pl modified to use it for user input and output, each done 
completely with a single method call.  That module is robust enough to work with 
CGI, mod_perl, command line.  Of course, this code is separate and optional for 
a reason, so not to limit your flexability in choosing other options.  The code 
below shows how to use CGI::Portable by itself when you manually do the I/O.>

	#!/usr/bin/perl
	use strict;

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

=head2 Content of settings file "config.pl"

	my $rh_prefs = {
		title => 'Welcome to Aardvark',
		credits => '<P>This program copyright 2001 Darren Duncan.</P>',
		screens => {
			one => {
				'link' => 'Fill Out A Form',
				mod_name => 'Tiger',
				mod_prefs => {
					field_defs => [
						{
							visible_title => "What's your name?",
							type => 'textfield',
							name => 'name',
						}, {
							visible_title => "What's the combination?",
							type => 'checkbox_group',
							name => 'words',
							'values' => ['eenie', 'meenie', 'minie', 'moe'],
							default => ['eenie', 'minie'],
						}, {
							visible_title => "What's your favorite colour?",
							type => 'popup_menu',
							name => 'color',
							'values' => ['red', 'green', 'blue', 'chartreuse'],
						}, {
							type => 'submit', 
						},
					],
				},
			},
			two => {
				'link' => 'Fly Away',
				mod_name => 'Owl',
				mod_prefs => {
					fly_to => 'http://www.perl.com',
				},
			}, 
			three => {
				'link' => 'Don\'t Go Here',
				mod_name => 'Camel',
				mod_subdir => 'files',
				mod_prefs => {
					priv => 'private.txt',
					prot => 'protected.txt',
					publ => 'public.txt',
				},
			},
			four => {
				'link' => 'Look At Some Files',
				mod_name => 'Panda',
				mod_prefs => {
					food => 'plants',
					color => 'black and white',
					size => 'medium',
					files => [qw( priv prot publ )],
					file_reader => '/three',
				},
			}, 
		},
	};

=head2 Content of fat main program component "Aardvark.pm"

I<This module acts sort of like CGI::WPM::MultiPage.>

	package Aardvark;
	use strict;
	use CGI::Portable;

	sub main {
		my ($class, $globals) = @_;
		my $users_choice = $globals->current_user_path_element();
		my $rh_screens = $globals->pref( 'screens' );
		
		if( my $rh_screen = $rh_screens->{$users_choice} ) {
			my $inner = $globals->make_new_context();
			$inner->inc_user_path_level();
			$inner->navigate_url_path( $users_choice );
			$inner->navigate_file_path( $rh_screen->{mod_subdir} );
			$inner->set_prefs( $rh_screen->{mod_prefs} );
			$inner->call_component( $rh_screen->{mod_name} );
			$globals->take_context_output( $inner );
		
		} else {
			$globals->set_page_body( "<P>Please choose a screen to view.</P>" );
			foreach my $key (keys %{$rh_screens}) {
				my $label = $rh_screens->{$key}->{link};
				my $url = $globals->url_as_string( $key );
				$globals->append_page_body( "<BR><A HREF=\"$url\">$label</A>" );
			}
		}
		
		$globals->page_title( $globals->pref( 'title' ) );
		$globals->prepend_page_body( "<H1>".$globals->page_title()."</H1>\n" );
		$globals->append_page_body( $globals->pref( 'credits' ) );
	}

	1;

=head2 Content of component module "Tiger.pm"

I<This module acts sort of like CGI::WPM::MailForm without the emailing.>

	package Tiger;
	use strict;
	use CGI::Portable;
	use HTML::FormTemplate;

	sub main {
		my ($class, $globals) = @_;
		my $ra_field_defs = $globals->resolve_prefs_node_to_array( 
			$globals->pref( 'field_defs' ) );
		if( $globals->get_error() ) {
			$globals->set_page_body( 
				"Sorry I can not do that form thing now because we are missing ", 
				"critical settings that say what the questions are.",
				"Reason: ", $globals->get_error(),
			);
			$globals->add_no_error();
			return( 0 );
		}
		my $form = HTML::FormTemplate->new();
		$form->form_submit_url( $globals->recall_url() );
		$form->field_definitions( $ra_field_defs );
		$form->user_input( $globals->user_post() );
		$globals->set_page_body(
			'<H2>Here Are Some Questions</H2>',
			$form->make_html_input_form( 1 ),
			'<HR>',
			'<H2>Answers From Last Time If Any</H2>',
			$form->new_form() ? '' : $form->make_html_input_echo( 1 ),
		);
	}

	1;

=head2 Content of component module "Owl.pm"

I<This module acts sort of like CGI::WPM::Redirect.>

	package Owl;
	use strict;
	use CGI::Portable;

	sub main {
		my ($class, $globals) = @_;
		my $url = $globals->pref( 'fly_to' );
		$globals->http_status_code( '301 Moved' );
		$globals->http_redirect_url( $url );
	}

	1;

=head2 Content of component module "Camel.pm"

I<This module acts sort of like CGI::WPM::Static.>

	package Camel;
	use strict;
	use CGI::Portable;

	sub main {
		my ($class, $globals) = @_;
		my $users_choice = $globals->current_user_path_element();
		my $filename = $globals->pref( $users_choice );
		my $filepath = $globals->physical_filename( $filename );
		SWITCH: {
			$globals->add_no_error();
			open( FH, $filepath ) or do {
				$globals->add_virtual_filename_error( 'open', $filename );
				last SWITCH;
			};
			local $/ = undef;
			defined( my $file_content = <FH> ) or do {
				$globals->add_virtual_filename_error( "read from", $filename );
				last SWITCH;
			};
			close( FH ) or do {
				$globals->add_virtual_filename_error( "close", $filename );
				last SWITCH;
			};
			$globals->set_page_body( $file_content );
		}
		if( $globals->get_error() ) {
			$globals->append_page_body( 
				"Can't show requested screen: ".$globals->get_error() );
			$globals->add_no_error();
		}
	}

	1;

=head2 Content of component module "Panda.pm"

I<This module acts sort of like nothing I've ever seen.>

	package Panda;
	use strict;
	use CGI::Portable;

	sub main {
		my ($class, $globals) = @_;
		$globals->set_page_body( <<__endquote );
	<P>Food: @{[$globals->pref( 'food' )]}
	<BR>Color: @{[$globals->pref( 'color' )]}
	<BR>Size: @{[$globals->pref( 'size' )]}</P>
	<P>Now let's look at some files; take your pick:
	__endquote
		$globals->navigate_url_path( $globals->pref( 'file_reader' ) );
		foreach my $frag (@{$globals->pref( 'files' )}) {
			my $url = $globals->url_as_string( $frag );
			$globals->append_page_body( "<BR><A HREF=\"$url\">$frag</A>" );
		}
		$globals->append_page_body( "</P>" );
	}

	1;

=head1 DESCRIPTION

The CGI::Portable class is a framework intended to support complex web
applications that are easily portable across servers because common
environment-specific details are abstracted away, including the file system type,
the web server type, and your project's location in the file system or uri
hierarchy.

Also abstracted away are details related to how users of your applications
arrange instance config/preferences data across single or multiple files, so they
get more flexability in how to use your application without you writing the code
to support it. So your apps are easier to make data-controlled.

Application cores would use CGI::Portable as an interface to the server they are
running under, where they receive user input through it and they return a
response (HTML page or other data type) to the user through it. Since
CGI::Portable should be able to express all of their user input or output needs,
your application cores should run well under CGI or mod_perl or IIS or a
Perl-based server or a command line without having code that supports each type's
individual needs.

That said, CGI::Portable doesn't contain any user input/output code of its own,
but allows you to use whatever platform-specific code or modules you wish between
it and the actual server. By using my module as an abstraction layer, your own
program core doesn't need to know which platform-specific code it is talking to.

As a logical extension to the interfacing functionality, CGI::Portable makes it
easier for you to divide your application into atonomous components, each of
which acts like it is its own application core with user input and instance
config data provided to it and a recepticle for its user output provided. This
module would be an interface between the components.

=head1 SIMILAR MODULES

Based on the above, you could conceivably say CGI::Portable has similarities to
these modules: CGI::Screen, CGI::MxScreen, CGI::Application, CGI::BuildPage,
CGI::Response, HTML::Mason, CGI, and others.

To start with, all of the above modules do one or more of: storing and providing
access to user input, helping to organize access to multiple user screens or
application modes, collecting and storing output for the user, and so on.

Some ways that the modules are different from mine are: level of complexity,
because my module is simpler than HTML::Mason and CGI::MxScreen and CGI,
but it is more complex and/or comprehensive than the others; functionality,
because it takes portability between servers to a new level by being agnostic on
both ends, where the other solutions are all/mostly tied to specific server types
since they do the I/O by themselves; my module also does filesystem translation
and some settings management, and I don't think any of the others do; I have
built-in functionality for organizing user screens hierarchically, called
user_path/url_path (in/out equivalents); I keep query params and post params
whereas most of the others use CGI.pm which combines them together; more
differences.

=head1 A DIFFERENT OVERVIEW

This class is designed primarily as a data structure that intermediates between 
your large central program logic and the small shell part of your code that knows 
anything specific about your environment.  The way that this works is that the 
shell code instantiates an CGI::Portable object and stores any valid user 
input in it, gathered from the appropriate places in the current environment.  
Then the central program is started and given the CGI::Portable object, from 
which it takes stored user input and performs whatever tasks it needs to.  The 
central program stores its user output in the same CGI::Portable object and 
then quits.  Finally, the shell code takes the stored user output from the 
CGI::Portable object and does whatever is necessary to send it to the user.  
Similarly, your thin shell code knows where to get the instance-specific file 
system and stored program settings data, which it gives to the CGI::Portable 
object along with the user input.

Here is a diagram:

	            YOUR THIN             CGI::Portable          YOUR FAT "CORE" 
	USER <----> "MAIN" CONFIG, <----> INTERFACE LAYER <----> PROGRAM LOGIC
	            I/O SHELL             FRAMEWORK              FUNCTIONALITY
	            (may be portable)     (portable)             (portable)

This class does not gather any user input or send any user input by itself, but
expects your thin program instance shell to do that.  The rationale is both for
keeping this class simpler and for keeping it compatible with all types of web
servers instead of just the ones it knows about.  So it works equally well with
CGI under any server or mod_perl or when your Perl is its own web server or when
you are debugging on the command line.

Because your program core uses this class to communicate with its "superior", it 
can be written the same way regardless of what platform it is running on.  The 
interface that it needs to written to is consistent across platforms.  An 
analogy to this is that the core always plays in the same sandbox and that 
environment is all it knows; you can move the sandbox anywhere you want and its 
occupant doesn't have to be any the wiser to how the outside world had changed.  

From there, it is a small step to breaking your program core into reusable 
components and using CGI::Portable as an interface between them.  Each 
component exists in its own sandbox and acts like it is its own core program, 
with its own task to produce an html page or other http response, and with its 
own set of user input and program settings to tell it how to do its job.  
Depending on your needs, each "component" instance could very well be its own 
complete application, or it would in fact be a subcontractee of another one.  
In the latter case, the "subcontractor" component may have other components do 
a part of its own task, and then assemble a derivative work as its own output.  

When one component wants another to do work for it, the first one instantiates 
a new CGI::Portable object which it can pass on any user input or settings 
data that it wishes, and then provides this to the second component; the second 
one never has to know where its CGI::Portable object it has came from, but 
that everything it needs to know for its work is right there.  This class 
provides convenience methods like make_new_context() to simplify this task by 
making a partial clone that replicates input but not output data.

Due to the way CGI::Portable stores program settings and other input/output 
data, it lends itself well to supporting data-driven applications.  That is, 
your application components can be greatly customizable as to their function by 
simply providing instances of them with different setup data.  If any component 
is so designed, its own config instructions can detail which other components it 
subcontracts, as well as what operating contexts it sets up for them.  This 
results in a large variety of functionality from just a small set of components.  

Another function that CGI::Portable provides for component management is that 
there is limited protection for components that are not properly designed to be 
kept from harming other ones.  You see, any components designed a certain way can 
be invoked by CGI::Portable itself at the request of another component.  
This internal call is wrapped in an eval block such that if a component fails to 
compile or has a run-time exception, this class will log an error to the effect 
and the component that called it continues to run.  Also, called components get 
a different CGI::Portable object than the parent, so that if they mess around 
with the stored input/output then the parent component's own data isn't lost.  
It is the parent's own choice as to which output of its child that it decides to 
copy back into its own output, with or without further processing.

Note that the term "components" above suggests that each one is structured as 
a Perl 5 module and is called like one; the module should have a method called 
main() that takes an CGI::Portable object as its argument and has the 
dispatch code for that component.  Of course, it is up to you.

See these major headings below for information on specific functionalities of 
this module: METHODS FOR DEBUGGING, METHODS FOR ERROR MESSAGES, 
METHODS FOR THE VIRTUAL FILE SYSTEM, METHODS FOR INSTANCE PREFERENCES, 
METHODS FOR USER INPUT, METHODS FOR MAKING NEW SELF-REFERENCING URLS, 
METHODS FOR MAKING RECALL URLS, METHODS FOR MAKING NEW HTML PAGES, 
METHODS FOR MAKING NEW HTTP RESPONSES, METHODS FOR MISCELLANEOUS OBJECT SERVICES, 
METHODS FOR CONTEXT SWITCHING, METHODS FOR SEARCH AND REPLACE, as well as some 
of the individual method descriptors.  The above list basically summarizes what 
functionality CGI::Portable provides.

=cut

######################################################################

# Names of properties for objects of this class are declared here:
my $KEY_IS_DEBUG = 'is_debug';  # boolean - a flag to say we are debugging
my $KEY_ERRORS = 'errors';  # array - a list of short error messages
my $KEY_FILE_PATH = 'file_path';  # FVP - tracks filesystem loc of our files
my $KEY_PREFS = 'prefs';  # hash - tracks our current file-based preferences

# These properties are set from the user input
my $KEY_UI_PATH = 'ui_path';  # FVP - stores virtual url path user requested
my $KEY_UI_QUER = 'ui_quer';  # CMVH - stores parsed user input query
my $KEY_UI_POST = 'ui_post';  # CMVH - stores parsed user input post
my $KEY_UI_COOK = 'ui_cook';  # CMVH - stores parsed user input cookies

# These properties are used when making new self-referencing urls in output
my $KEY_URL_BASE = 'url_base';  # string - stores joined host, script_name, etc
my $KEY_URL_PATH = 'url_path';  # FVP - virtual path used in s-r urls
my $KEY_URL_QUER = 'url_quer';  # DMVH - holds query params to put in all urls
my $KEY_URL_PIPI = 'url_pipi';  # boolean - true if path goes in PATH_INFO
my $KEY_URL_PIQU = 'url_piqu';  # boolean - true if path goes in a query param
my $KEY_URL_PQPN = 'url_pqpn';  # string - if path in query; this is param name

# These properties will be combined into the output page if it is text/html
my $KEY_PAGE_TITL = 'page_titl';  # string - new HTML title
my $KEY_PAGE_AUTH = 'page_auth';  # string - new HTML author
my $KEY_PAGE_META = 'page_meta';  # hash - new HTML meta keys/values
my $KEY_PAGE_CSSR = 'page_cssr';  # array - new HTML css file urls
my $KEY_PAGE_CSSC = 'page_cssc';  # array - new HTML css embedded code
my $KEY_PAGE_HEAD = 'page_head';  # array - raw misc content for HTML head
my $KEY_PAGE_BATR = 'page_batr';  # hash - attribs for HTML body tag
my $KEY_PAGE_BODY = 'page_body';  # array - raw content for HTML body

# These properties would go in output HTTP headers and body
my $KEY_HTTP_STAT = 'http_stat';  # string - HTTP status code; first to output
my $KEY_HTTP_COTY = 'http_coty';  # string - stores Content-type of outp
my $KEY_HTTP_REDI = 'http_redi';  # string - stores URL to redirect to
my $KEY_HTTP_COOK = 'http_cook';  # array of DMVH - stores outgoing cookies
my $KEY_HTTP_HEAD = 'http_head';  # hash - stores misc HTTP headers keys/values
my $KEY_HTTP_BODY = 'http_body';  # string - stores raw HTTP body if wanted
my $KEY_HTTP_BINA = 'http_bina';  # boolean - true if HTTP body is binary

# These properties are special prefs to be set once and global avail (copied)
my $KEY_PREF_APIT = 'pref_apit';  # string - application instance title
my $KEY_PREF_MNAM = 'pref_mnam';  # string - maintainer name
my $KEY_PREF_MEAD = 'pref_mead';  # string - maintainer email address
my $KEY_PREF_MESP = 'pref_mesp';  # string - maintainer email screen url path
my $KEY_PREF_SMTP = 'pref_smtp';  # string - smtp host domain/ip to use
my $KEY_PREF_TIME = 'pref_time';  # number - timeout in seconds for smtp connect

# This property is generally static across all derived objects for misc sharing
my $KEY_MISC_OBJECTS = 'misc_objects';  # hash - holds misc objects we may need

######################################################################

=head1 SYNTAX

This class does not export any functions or methods, so you need to call them
using object notation.  This means using B<Class-E<gt>function()> for functions
and B<$object-E<gt>method()> for methods.  If you are inheriting this class for
your own modules, then that often means something like B<$self-E<gt>method()>. 

=head1 CONSTRUCTOR FUNCTIONS AND METHODS

These functions and methods are involved in making new CGI::Portable objects.

=head2 new([ FILE_ROOT[, FILE_DELIM[, PREFS]] ])

This function creates a new CGI::Portable (or subclass) object and
returns it.  All of the method arguments are passed to initialize() as is; please
see the POD for that method for an explanation of them.

=cut

######################################################################

sub new {
	my $class = shift( @_ );
	my $self = bless( {}, ref($class) || $class );
	$self->initialize( @_ );
	return( $self );
}

######################################################################

=head2 initialize([ FILE_ROOT[, FILE_DELIM[, PREFS]] ])

This method is used by B<new()> to set the initial properties of objects that it
creates.  The optional 3 arguments are used in turn to set the properties 
accessed by these methods: file_path_root(), file_path_delimiter(), set_prefs().

=cut

######################################################################

sub initialize {
	my ($self, $file_root, $file_delim, $prefs) = @_;

	$self->{$KEY_IS_DEBUG} = undef;
	$self->{$KEY_ERRORS} = [];
	$self->{$KEY_FILE_PATH} = File::VirtualPath->new();
	$self->{$KEY_PREFS} = {};

	$self->{$KEY_UI_PATH} = File::VirtualPath->new();
	$self->{$KEY_UI_QUER} = CGI::MultiValuedHash->new();
	$self->{$KEY_UI_POST} = CGI::MultiValuedHash->new();
	$self->{$KEY_UI_COOK} = CGI::MultiValuedHash->new();

	$self->{$KEY_URL_BASE} = 'http://localhost/';
	$self->{$KEY_URL_PATH} = File::VirtualPath->new();
	$self->{$KEY_URL_QUER} = CGI::MultiValuedHash->new();
	$self->{$KEY_URL_PIPI} = 1;
	$self->{$KEY_URL_PIQU} = undef;
	$self->{$KEY_URL_PQPN} = 'path';

	$self->{$KEY_PAGE_TITL} = undef;
	$self->{$KEY_PAGE_AUTH} = undef;
	$self->{$KEY_PAGE_META} = {};
	$self->{$KEY_PAGE_CSSR} = [];
	$self->{$KEY_PAGE_CSSC} = [];
	$self->{$KEY_PAGE_HEAD} = [];
	$self->{$KEY_PAGE_BATR} = {};
	$self->{$KEY_PAGE_BODY} = [];

	$self->{$KEY_HTTP_STAT} = '200 OK';
	$self->{$KEY_HTTP_COTY} = 'text/html';
	$self->{$KEY_HTTP_REDI} = undef;
	$self->{$KEY_HTTP_COOK} = [];
	$self->{$KEY_HTTP_HEAD} = {};
	$self->{$KEY_HTTP_BODY} = undef;
	$self->{$KEY_HTTP_BINA} = undef;
	
	$self->{$KEY_PREF_APIT} = 'Untitled Application';
	$self->{$KEY_PREF_MNAM} = 'Webmaster';
	$self->{$KEY_PREF_MEAD} = 'webmaster@localhost';
	$self->{$KEY_PREF_MESP} = undef;
	$self->{$KEY_PREF_SMTP} = 'localhost';
	$self->{$KEY_PREF_TIME} = '30';

	$self->{$KEY_MISC_OBJECTS} = {};

	$self->file_path_root( $file_root );
	$self->file_path_delimiter( $file_delim );
	$self->set_prefs( $prefs );
}

######################################################################

=head2 clone([ CLONE ])

This method initializes a new object to have all of the same properties of the
current object and returns it.  This new object can be provided in the optional
argument CLONE (if CLONE is an object of the same class as the current object);
otherwise, a brand new object of the current class is used.  Only object
properties recognized by CGI::Portable are set in the clone; other
properties are not changed.

=cut

######################################################################

sub clone {
	my ($self, $clone) = @_;
	ref($clone) eq ref($self) or $clone = bless( {}, ref($self) );

	$clone->{$KEY_IS_DEBUG} = $self->{$KEY_IS_DEBUG};
	$clone->{$KEY_ERRORS} = [@{$self->{$KEY_ERRORS}}];
	$clone->{$KEY_FILE_PATH} = $self->{$KEY_FILE_PATH}->clone();
	$clone->{$KEY_PREFS} = {%{$self->{$KEY_PREFS}}};

	$clone->{$KEY_UI_PATH} = $self->{$KEY_UI_PATH}->clone();
	$clone->{$KEY_UI_QUER} = $self->{$KEY_UI_QUER}->clone();
	$clone->{$KEY_UI_POST} = $self->{$KEY_UI_POST}->clone();
	$clone->{$KEY_UI_COOK} = $self->{$KEY_UI_COOK}->clone();

	$clone->{$KEY_URL_BASE} = $self->{$KEY_URL_BASE};
	$clone->{$KEY_URL_PATH} = $self->{$KEY_URL_PATH}->clone();
	$clone->{$KEY_URL_QUER} = $self->{$KEY_URL_QUER}->clone();
	$clone->{$KEY_URL_PIPI} = $self->{$KEY_URL_PIPI};
	$clone->{$KEY_URL_PIQU} = $self->{$KEY_URL_PIQU};
	$clone->{$KEY_URL_PQPN} = $self->{$KEY_URL_PQPN};

	$clone->{$KEY_PAGE_TITL} = $self->{$KEY_PAGE_TITL};
	$clone->{$KEY_PAGE_AUTH} = $self->{$KEY_PAGE_AUTH};
	$clone->{$KEY_PAGE_META} = {%{$self->{$KEY_PAGE_META}}};
	$clone->{$KEY_PAGE_CSSR} = [@{$self->{$KEY_PAGE_CSSR}}];
	$clone->{$KEY_PAGE_CSSC} = [@{$self->{$KEY_PAGE_CSSC}}];
	$clone->{$KEY_PAGE_HEAD} = [@{$self->{$KEY_PAGE_HEAD}}];
	$clone->{$KEY_PAGE_BATR} = {%{$self->{$KEY_PAGE_BATR}}};
	$clone->{$KEY_PAGE_BODY} = [@{$self->{$KEY_PAGE_BODY}}];

	$clone->{$KEY_HTTP_STAT} = $self->{$KEY_HTTP_STAT};
	$clone->{$KEY_HTTP_COTY} = $self->{$KEY_HTTP_COTY};
	$clone->{$KEY_HTTP_REDI} = $self->{$KEY_HTTP_REDI};
	$clone->{$KEY_HTTP_COOK} = [map { $_->clone() } @{$self->{$KEY_HTTP_COOK}}];
	$clone->{$KEY_HTTP_HEAD} = {%{$self->{$KEY_HTTP_HEAD}}};
	$clone->{$KEY_HTTP_BODY} = $self->{$KEY_HTTP_BODY};
	$clone->{$KEY_HTTP_BINA} = $self->{$KEY_HTTP_BINA};

	$clone->{$KEY_PREF_APIT} = $self->{$KEY_PREF_APIT};
	$clone->{$KEY_PREF_MNAM} = $self->{$KEY_PREF_MNAM};
	$clone->{$KEY_PREF_MEAD} = $self->{$KEY_PREF_MEAD};
	$clone->{$KEY_PREF_MESP} = $self->{$KEY_PREF_MESP};
	$clone->{$KEY_PREF_SMTP} = $self->{$KEY_PREF_SMTP};
	$clone->{$KEY_PREF_TIME} = $self->{$KEY_PREF_TIME};

	$clone->{$KEY_MISC_OBJECTS} = $self->{$KEY_MISC_OBJECTS};  # copy hash ref

	return( $clone );
}

######################################################################

=head1 METHODS FOR DEBUGGING

=head2 is_debug([ VALUE ])

This method is an accessor for the "is debug" boolean property of this object,
which it returns.  If VALUE is defined, this property is set to it.  If this
property is true then it indicates that the program is currently being debugged
by the owner/maintainer; if it is false then the program is being run by a normal
user.  How or whether the program reacts to this fact is quite arbitrary.  
For example, it may just keep a separate set of usage logs or append "debug" 
messages to email or web pages it makes.

=cut

######################################################################

sub is_debug {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_IS_DEBUG} = $new_value;
	}
	return( $self->{$KEY_IS_DEBUG} );
}

######################################################################

=head1 METHODS FOR ERROR MESSAGES

These methods are accessors for the "error list" property of this object, 
which is designed to accumulate any error strings that should be printed to the 
program's error log or shown to the user before the program exits.  What 
constitutes an error condition is up to you, but the suggested use is for things 
that are not the web user's fault, such as problems compiling or calling program 
modules, or problems using file system files for settings or data.  The errors 
list is not intended to log invalid user input, which would be common activity.
Since some errors are non-fatal and other parts of your program would still 
work, it is possible for several errors to happen in parallel; hence a list.  
At program start-up this list starts out empty.

An extension to this feature is the concept of "no error" messages (undefined 
strings) which if used indicate that the last operation *did* work.  This gives 
you the flexability to always record the result of an operation for acting on 
later.  If you use get_error() in a boolean context then it would be true if the 
last noted operation had an error and false if it didn't.  You can also issue an 
add_no_error() to mask errors that have been dealt with so they don't continue 
to look unresolved.

=head2 get_errors()

This method returns a list of the stored error messages with any undefined 
strings (no error) filtered out.

=head2 get_error([ INDEX ])

This method returns a single error message.  If the numerical argument INDEX is 
defined then the message is taken from that element in the error list.  
INDEX defaults to -1 if not defined, so the most recent message is returned.

=head2 add_error( MESSAGE )

This method appends the scalar argument MESSAGE to the error list.

=head2 add_no_error()

This message appends an undefined value to the error list, a "no error" message.

=head2 add_virtual_filename_error( UNIQUE_PART, FILENAME[, REASON] )

This message constructs a new error message using its arguments and appends it to
the error list.  You can call this after doing a file operation that failed where
UNIQUE_PART is a sentence fragment like "open" or "read from" and FILENAME is the
relative portion of the file name.  The new message looks like 
"can't [UNIQUE_PART] file '[FILEPATH]': $!" where FILEPATH is defined as the 
return value of "virtual_filename( FILENAME )".  If the optional argument REASON 
is defined then its value is used in place of $!, so you can use this method for 
errors relating to a file where $! wouldn't have an appropriate value.

=head2 add_physical_filename_error( UNIQUE_PART, FILENAME[, REASON] )

This message constructs a new error message using its arguments and appends it to
the error list.  You can call this after doing a file operation that failed where
UNIQUE_PART is a sentence fragment like "open" or "read from" and FILENAME is the
relative portion of the file name.  The new message looks like 
"can't [UNIQUE_PART] file '[FILEPATH]': $!" where FILEPATH is defined as the 
return value of "physical_filename( FILENAME )".  If the optional argument REASON 
is defined then its value is used in place of $!, so you can use this method for 
errors relating to a file where $! wouldn't have an appropriate value.

=cut

######################################################################

sub get_errors {
	return( grep { defined($_) } @{$_[0]->{$KEY_ERRORS}} );
}

sub get_error {
	my ($self, $index) = @_;
	defined( $index ) or $index = -1;
	return( $self->{$KEY_ERRORS}->[$index] );
}

sub add_error {
	my ($self, $message) = @_;
	push( @{$self->{$KEY_ERRORS}}, $message );
}

sub add_no_error {
	push( @{$_[0]->{$KEY_ERRORS}}, undef );
}

sub add_virtual_filename_error {
	my ($self, $unique_part, $filename, $reason) = @_;
	my $filepath = $self->virtual_filename( $filename );
	defined( $reason ) or $reason = $!;
	$self->add_error( "can't $unique_part file '$filepath': $reason" );
}

sub add_physical_filename_error {
	my ($self, $unique_part, $filename, $reason) = @_;
	my $filepath = $self->physical_filename( $filename );
	defined( $reason ) or $reason = $!;
	$self->add_error( "can't $unique_part file '$filepath': $reason" );
}

######################################################################

=head1 METHODS FOR THE VIRTUAL FILE SYSTEM

These methods are accessors for the "file path" property of this object, which is
designed to facilitate easy portability of your application across multiple file
systems or across different locations in the same file system.  It maintains a
"virtual file system" that you can use, within which your program core owns the
root directory.

Your program core would take this virtual space and organize it how it sees fit
for configuration and data files, including any use of subdirectories that is
desired.  This class will take care of mapping the virtual space onto the real
one, in which your virtual root is actually a subdirectory and your path
separators may or may not be UNIXy ones.

If this class is faithfully used to translate your file system operations, then
you will stay safely within your project root directory at all times.  Your core
app will never have to know if the project is moved around since details of the
actual file paths, including level delimiters, has been abstracted away.  It will
still be able to find its files.  Only your program's thin instance startup shell
needs to know the truth.

The file path property is a File::VirtualPath object so please see the POD for 
that class to learn about its features.

=head2 get_file_path_ref()

This method returns a reference to the file path object which you can then 
manipulate directly with File::VirtualPath methods.

=head2 file_path_root([ VALUE ])

This method is an accessor for the "physical root" string property of the file 
path, which it returns.  If VALUE is defined then this property is set to it.
This property says where your project directory is actually located in the 
current physical file system, and is used in translations from the virtual to 
the physical space.  The only part of your program that should set this method 
is your thin startup shell; the rest should be oblivious to it.

=head2 file_path_delimiter([ VALUE ])

This method is an accessor for the "physical delimiter" string property of the 
file path, which it returns.  If VALUE is defined then this property is set to 
it.  This property says what character is used to delimit directory path levels 
in your current physical file system, and is used in translations from the 
virtual to the physical space.  The only part of your program that should set 
this method is your thin startup shell; the rest should be oblivious to it.

=head2 file_path([ VALUE ])

This method is an accessor to the "virtual path" array property of the file path, 
which it returns.  If VALUE is defined then this property is set to it; it can 
be an array of path levels or a string representation in the virtual space.
This method returns an array ref having the current virtual file path.

=head2 file_path_string([ TRAILER ])

This method returns a string representation of the file path in the virtual 
space.  If the optional argument TRAILER is true, then a virtual file path 
delimiter, "/" by default, is appended to the end of the returned value.

=head2 navigate_file_path( CHANGE_VECTOR )

This method updates the "virtual path" property of the file path by taking the 
current one and applying CHANGE_VECTOR to it using the FVP's chdir() method.  
This method returns an array ref having the changed virtual file path.

=head2 virtual_filename( CHANGE_VECTOR[, WANT_TRAILER] )

This method uses CHANGE_VECTOR to derive a new path in the virtual file-system 
relative to the current one and returns it as a string.  If WANT_TRAILER is true 
then the string has a path delimiter appended; otherwise, there is none.

=head2 physical_filename( CHANGE_VECTOR[, WANT_TRAILER] )

This method uses CHANGE_VECTOR to derive a new path in the real file-system 
relative to the current one and returns it as a string.  If WANT_TRAILER is true 
then the string has a path delimiter appended; otherwise, there is none.

=cut

######################################################################

sub get_file_path_ref {
	return( $_[0]->{$KEY_FILE_PATH} );  # returns ref for further use
}

sub file_path_root {
	my ($self, $new_value) = @_;
	return( $self->{$KEY_FILE_PATH}->physical_root( $new_value ) );
}

sub file_path_delimiter {
	my ($self, $new_value) = @_;
	return( $self->{$KEY_FILE_PATH}->physical_delimiter( $new_value ) );
}

sub file_path {
	my ($self, $new_value) = @_;
	return( $self->{$KEY_FILE_PATH}->path( $new_value ) );
}

sub file_path_string {
	my ($self, $trailer) = @_;
	return( $self->{$KEY_FILE_PATH}->path_string( $trailer ) );
}

sub navigate_file_path {
	my ($self, $chg_vec) = @_;
	return( $self->{$KEY_FILE_PATH}->chdir( $chg_vec ) );
}

sub virtual_filename {
	my ($self, $chg_vec, $trailer) = @_;
	return( $self->{$KEY_FILE_PATH}->child_path_string( $chg_vec, $trailer ) );
}

sub physical_filename {
	my ($self, $chg_vec, $trailer) = @_;
	return( $self->{$KEY_FILE_PATH}->physical_child_path_string( 
		$chg_vec, $trailer ) );
}

######################################################################

=head1 METHODS FOR INSTANCE PREFERENCES

These methods are accessors for the "preferences" property of this object, which 
is designed to facilitate easy access to your application instance settings.
The "preferences" is a hierarchical data structure which has a hash as its root 
and can be arbitrarily complex from that point on.  A hash is used so that any 
settings can be accessed by name; the hierarchical nature comes from any 
setting values that are references to non-scalar values, or resolve to such.

CGI::Portable makes it easy for your preferences structure to scale across 
any number of storage files, helping with memory and speed efficiency.  At 
certain points in your program flow, branches of the preferences will be followed 
until a node is reached that your program wants to be a hash.  At that point, 
this node can be given back to this class and resolved into a hash one way or 
another.  If it already is a hash ref then it is given back as is; otherwise it 
is taken as a filename for a Perl file which when evaluated with "do" returns 
a hash ref.  This filename would be a relative path in the virtual file system 
and this class would resolve it properly.

Since the fact of hash-ref-vs-filename is abstracted from your program, this 
makes it easy for your data itself to determine how the structure is segmented.  
The decision-making begins with the root preferences node that your thin config 
shell gives to CGI::Portable at program start-up.  What is resolved from 
that determines how any child nodes are gotten, and they determine their 
children.  Since this class handles such details, it is much easier to make your 
program data-controlled rather than code-controlled.  For instance, your startup 
shell may contain the entire preferences structure itself, meaning that you only 
need a single file to define a project instance.  Or, your startup shell may 
just have a filename for where the preferences really are, making it minimalist.  
Depending how your preferences are segmented, only the needed parts actually get 
loaded, so we save resources.

=head2 resolve_prefs_node_to_hash( RAW_NODE )

This method takes a raw preferences node, RAW_NODE, and resolves it into a hash 
ref, which it returns.  If RAW_NODE is a hash ref then this method performs a 
single-level copy of it and returns a new hash ref.  Otherwise, this method 
takes the argument as a filename and tries to execute it.  If the file fails to 
execute for some reason or it doesn't return a hash ref, then this method adds 
a file error message and returns an empty hash ref.  The file is executed with 
"do [FILEPATH]" where FILEPATH is defined as the return value of 
"physical_filename( FILENAME )".  The error message uses a virtual path.

=head2 resolve_prefs_node_to_array( RAW_NODE )

This method takes a raw preferences node, RAW_NODE, and resolves it into an array 
ref, which it returns.  If RAW_NODE is a hash ref then this method performs a 
single-level copy of it and returns a new array ref.  Otherwise, this method 
takes the argument as a filename and tries to execute it.  If the file fails to 
execute for some reason or it doesn't return an array ref, then this method adds 
a file error message and returns an empty array ref.  The file is executed with 
"do [FILEPATH]" where FILEPATH is defined as the return value of 
"physical_filename( FILENAME )".  The error message uses a virtual path.

=head2 get_prefs_ref()

This method returns a reference to the internally stored "preferences" hash.

=head2 set_prefs( VALUE )

This method sets this object's preferences property with the return value of 
"resolve_prefs_node_to_hash( VALUE )", even if VALUE is not defined.

=head2 pref( KEY[, VALUE] )

This method is an accessor to individual settings in this object's preferences 
property, and returns the setting value whose name is defined in the scalar 
argument KEY.  If the optional scalar argument VALUE is defined then it becomes 
the value for this setting.  All values are set or fetched with a scalar copy.

=cut

######################################################################

sub resolve_prefs_node_to_hash {
	my ($self, $raw_node) = @_;
	if( ref( $raw_node ) eq 'HASH' ) {
		return( {%{$raw_node}} );
	} else {
		$self->add_no_error();
		my $filepath = $self->physical_filename( $raw_node );
		my $result = do $filepath;
		if( ref( $result ) eq 'HASH' ) {
			return( $result );
		} else {
			$self->add_virtual_filename_error( 
				'obtain required preferences hash from', $raw_node, 
				defined( $result ) ? "result not a hash ref, but '$result'" : 
				$@ ? "compilation or runtime error of '$@'" : undef );
			return( {} );
		}
	}
}

sub resolve_prefs_node_to_array {
	my ($self, $raw_node) = @_;
	if( ref( $raw_node ) eq 'ARRAY' ) {
		return( [@{$raw_node}] );
	} else {
		$self->add_no_error();
		my $filepath = $self->physical_filename( $raw_node );
		my $result = do $filepath;
		if( ref( $result ) eq 'ARRAY' ) {
			return( $result );
		} else {
			$self->add_virtual_filename_error( 
				'obtain required preferences array from', $raw_node, 
				defined( $result ) ? "result not an array ref, but '$result'" : 
				$@ ? "compilation or runtime error of '$@'" : undef );
			return( [] );
		}
	}
}

sub get_prefs_ref {
	return( $_[0]->{$KEY_PREFS} );  # returns ref for further use
}

sub set_prefs {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) {
		$self->{$KEY_PREFS} = $self->resolve_prefs_node_to_hash( $new_value );
	}
}

sub pref {
	my ($self, $key, $new_value) = @_;
	if( defined( $new_value ) ) {
		$self->{$KEY_PREFS}->{$key} = $new_value;
	}
	return( $self->{$KEY_PREFS}->{$key} );
}

######################################################################

=head1 METHODS FOR USER INPUT

These methods are accessors for the "user input" properties of this object, 
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

=head1 METHODS FOR MAKING NEW SELF-REFERENCING URLS

These methods are accessors for the "url constructor" properties of this object,
which are designed to store components of the various information needed to make
new urls that call this script back in order to change from one interface screen
to another.  When the program is reinvoked with one of these urls, this
information becomes part of the user input, particularly the "user path" and
"user query".  You normally use the url_as_string() method to do the actual
assembly of these components, but the various "recall" methods also pay attention
to them.

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

=head1 METHODS FOR MAKING NEW HTML PAGES

These methods are designed to accumulate and assemble the components of a 
new HTML page, complete with body, title, meta tags, and cascading style sheets.  
The intent is for your core program to use these to store its user output, and 
then your thin program config shell would actually send the page to the user.  
Note that the "http body" property should not be used at the same time as these.

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

=head2 page_as_string()

This method assembles the various "page *" properties of this object into a 
complete HTML page and returns it as a string.  That is, it returns the 
cumulative string representation of those properties.  This consists of a 
prologue tag, a pair of "html" tags, and everything in between.
This method uses HTML::EasyTags to do the actual page assembly, and so the 
results are consistant with its abilities.

=cut

######################################################################

sub page_as_string {
	my $self = shift( @_ );
	my $html = HTML::EasyTags->new();
	my ($title,$author,$meta,$css_src,$css_code);

	$self->{$KEY_PAGE_AUTH} and $author = 
		$html->link( rev => 'made', href => "mailto:$self->{$KEY_PAGE_AUTH}" );

	%{$self->{$KEY_PAGE_META}} and $meta = join( '', map { 
		$html->meta_group( name => $_, value => $self->{$KEY_PAGE_META}->{$_} ) 
		} keys %{$self->{$KEY_PAGE_META}} );

	@{$self->{$KEY_PAGE_CSSR}} and $css_src = 
		$html->link_group( rel => 'stylesheet', type => 'text/css', 
		href => $self->{$KEY_PAGE_CSSR} );

	@{$self->{$KEY_PAGE_CSSC}} and $css_code = 
		$html->style( $html->comment_tag( $self->{$KEY_PAGE_CSSC} ) );

	return( join( '', 
		$html->start_html(
			$self->{$KEY_PAGE_TITL},
			[ $author, $meta, $css_src, $css_code, @{$self->{$KEY_PAGE_HEAD}} ], 
			$self->{$KEY_PAGE_BATR}, 
		), 
		@{$self->{$KEY_PAGE_BODY}},
		$html->end_html(),
	) );
}

######################################################################

=head1 METHODS FOR MAKING NEW HTTP RESPONSES

These methods are designed to accumulate and assemble the components of an HTTP 
response, complete with status code, content type, other headers, and a body.
The intent is for your core program to use these to store its user output, and 
then your thin program config shell would actually send the page to the user.  
These properties are initialized with values suitable for returning an HTML page.
The "http body" property is intended for use when you want to return raw content 
of any type, whether it is text or image or other binary.  It is a complement 
for the html assembling methods and should be left undefined if they are used.  

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

=head2 http_content_type([ VALUE ])

This method is an accessor for the "content type" scalar property of this object,
which it returns.  If VALUE is defined, this property is set to it.
This property is used in a new HTTP header to indicate the document type that 
the HTTP body is, such as text or image.  It defaults to "text/html" which means 
we are returning an HTML page.  This property would be used in a line like 
"Content-type: text/html".

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

=head2 get_http_cookie_refs()

This method returns a list of references for outgoing http cookies, each of which 
is a Data::MultiValuedHash object.  The list is 
returned as a literal list in list context and in an array ref in scalar context.

=head2 get_http_cookies()

This method returns a list of clones of outgoing http cookies.  The list is 
returned as a literal list in list context and in an array ref in scalar context.

=head2 add_http_cookies( COOKIE_LIST )

This method takes a literal list of initializers as COOKIE_LIST and creates a 
new Data::MultiValuedHash object from each one, appending them to the list of 
outgoing http cookies.  Each of these objects will make a single cookie, and 
keys for it include name, value, date, valid domains, and so forth.  This class 
doesn't interpret them itself, but rather the thin program config shell can take 
the DMVH objects and process, encode, deliver them as it sees fit.

=head2 delete_http_cookies()

This method deletes all of the internally stored outgoing http cookies.

=head2 get_http_cookie_ref([ INDEX ])

This method returns a reference to a single outgoing http cookie object, taken 
from index INDEX from the internal array of outgoing cookies.  INDEX defaults to 
-1 if not defined, the most recently added cookie.  If there is no object at 
INDEX then undef is returned.

=head2 get_http_cookie([ INDEX ])

This method returns a clone of a single outgoing http cookie object, taken 
from index INDEX from the internal array of outgoing cookies.  INDEX defaults to 
-1 if not defined, the most recently added cookie.  If there is no object at 
INDEX then undef is returned.

=cut

######################################################################

sub get_http_cookie_refs {
	my @cookies = @{$_[0]->{$KEY_HTTP_COOK}};
	return( wantarray ? @cookies : \@cookies );  
}

sub get_http_cookies {
	my @cookies = map { $_->clone() } @{$_[0]->{$KEY_HTTP_COOK}};
	return( wantarray ? @cookies : \@cookies );  
}

sub add_http_cookies {
	my ($self, @cookies) = @_;
	@cookies = map { Data::MultiValuedHash->new( 0, $_ ) } @cookies;
	push( @{$self->{$KEY_HTTP_COOK}}, @cookies );
}

sub delete_http_cookies {
	$_[0]->{$KEY_HTTP_COOK} = [];
}

sub get_http_cookie_ref {
	my ($self, $index) = @_;
	defined( $index ) or $index = -1;
	return( $self->{$KEY_HTTP_COOK}->[$index] );
}

sub get_http_cookie {
	my ($self, $index) = @_;
	defined( $index ) or $index = -1;
	my $cookie = $self->{$KEY_HTTP_COOK}->[$index];
	return( defined( $cookie ) ? $cookie->clone() : undef );
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

=head1 METHODS FOR GLOBAL PREFERENCES

These methods are designed to be accessors for a few "special" preferences that 
are global in the sense that they are stored separately from normal preferences 
and they only have to be set once in a parent context to be available to all 
child contexts and the application components that use them.  Each one has its 
own accessor method.  The information stored here is of the generic variety that 
could be used all over the application, such as the name of the application 
instance or the maintainer's name and email address, which can be used with 
error messages or other places where the maintainer would be contacted.

=head2 default_application_title([ VALUE ])

This method is an accessor for the "app instance title" string property of this 
object, which it returns.  If VALUE is defined, this property is set to it.  
This property can be used on about/error screens or email messages to indicate 
the title of this application instance.  You can call url_base() or recall_url() 
to provide an accompanying url in the emails if you wish.  This property 
defaults to "Untitled Application".

=head2 default_maintainer_name([ VALUE ])

This method is an accessor for the "maintainer name" string property of this 
object, which it returns.  If VALUE is defined, this property is set to it.  
This property can be used on about/error screens or email messages to indicate 
the name of the maintainer for this application instance, should you need to 
credit them or know who to contact.  This property defaults to "Webmaster".

=head2 default_maintainer_email_address([ VALUE ])

This method is an accessor for the "maintainer email" string property of this 
object, which it returns.  If VALUE is defined, this property is set to it.  
This property can be used on about/error screens or email messages to indicate 
the email address of the maintainer for this application instance, should you 
need to contact them or should this application need to send them an email.  
This property defaults to "webmaster@localhost".

=head2 default_maintainer_email_screen_url_path([ VALUE ])

This method is an accessor for the "maintainer screen" string property of this 
object, which it returns.  If VALUE is defined, this property is set to it.  
This property can be used on about/error pages as an "url path" that goes to 
the screen of your application giving information on how to contact the 
maintainer.  This property defaults to undefined, which means there is no screen 
in your app for this purpose; calling code that wants to use this would probably 
substitute the literal email address instead.

=head2 default_smtp_host([ VALUE ])

This method is an accessor for the "smtp host" string property of this 
object, which it returns.  If VALUE is defined, this property is set to it.  
This property can be used by your application as a default web domain or ip for 
the smtp server that it should use to send email with.  This property defaults 
to "localhost".

=head2 default_smtp_timeout([ VALUE ])

This method is an accessor for the "smtp timeout" number property of this 
object, which it returns.  If VALUE is defined, this property is set to it.  
This property can be used by your application when contacting an smtp server 
to say how many seconds it should wait before timing out.  This property 
defaults to 30.

=head2 maintainer_email_html([ LABEL ])

This method will selectively make a hyperlink that can be used by your users to 
contact the maintainer of this application.  If the "maintainer screen" property 
is defined then this method will make a hyperlink to that screen.  Otherwise, 
it makes an "mailto" hyperlink using the "maintainer email" address.

=cut

######################################################################

sub default_application_title {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) {
		$self->{$KEY_PREF_APIT} = $new_value;
	}
	return( $self->{$KEY_PREF_APIT} );
}

sub default_maintainer_name {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) {
		$self->{$KEY_PREF_MNAM} = $new_value;
	}
	return( $self->{$KEY_PREF_MNAM} );
}

sub default_maintainer_email_address {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) {
		$self->{$KEY_PREF_MEAD} = $new_value;
	}
	return( $self->{$KEY_PREF_MEAD} );
}

sub default_maintainer_email_screen_url_path {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) {
		$self->{$KEY_PREF_MESP} = $new_value;
	}
	return( $self->{$KEY_PREF_MESP} );
}

sub default_smtp_host {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) {
		$self->{$KEY_PREF_SMTP} = $new_value;
	}
	return( $self->{$KEY_PREF_SMTP} );
}

sub default_smtp_timeout {
	my ($self, $new_value) = @_;
	if( defined( $new_value ) ) {
		$self->{$KEY_PREF_TIME} = $new_value;
	}
	return( $self->{$KEY_PREF_TIME} );
}

sub maintainer_email_html {
	my ($self, $label) = @_;
	defined( $label ) or $label = 'e-mail';
	my $addy = $self->default_maintainer_email_address();
	my $path = $self->default_maintainer_email_screen_url_path();
	return( defined( $path ) ? 
		"<A HREF=\"@{[$self->url_as_string( $path )]}\">$label</A> ($addy)" : 
		"<A HREF=\"mailto:$addy\">$label</A> ($addy)" );
}

######################################################################

=head1 METHODS FOR MISCELLANEOUS OBJECT SERVICES

=head2 get_misc_objects_ref()

This method returns a reference to this object's "misc objects" hash property.  
This hash stores references to any objects you want to pass between program 
components with services that are beyond the scope of this class, such as 
persistent database handles.  This hash ref is static across all objects of 
this class that are derived from one another.

=head2 replace_misc_objects( HASH_REF )

This method lets this object have a "misc objects" property in common with 
another object that it doesn't already.  If the argument HASH_REF is a hash ref, 
then this property is set to it.

=head2 separate_misc_objects()

This method lets this object stop having a "misc objects" property in common 
with another, by replacing that property with a new empty hash ref.

=cut

######################################################################

sub get_misc_objects_ref {
	return( $_[0]->{$KEY_MISC_OBJECTS} );
}

sub replace_misc_objects {
	ref( $_[1] ) eq 'HASH' and $_[0]->{$KEY_MISC_OBJECTS} = $_[1];
}

sub separate_misc_objects {
	$_[0]->{$KEY_MISC_OBJECTS} = {};
}

######################################################################

=head1 METHODS FOR CONTEXT SWITCHING

These methods are designed to facilitate easy modularity of your application 
into multiple components by providing context switching functions for the parent 
component in a relationship.  While you could still use this class effectively 
without using them, they are available for your convenience.

=head2 make_new_context([ CONTEXT ])

This method initializes a new object of the current class and returns it.  This
new object has some of the current object's properties but lacks others.
Specifically, what does get copied is: debug state, file path, preferences, all 
types of user input, the url constructor properties, and misc objects.  What does 
not get copied is: error messages, html page components, and http response 
components.  As with clone(), the new object can be provided in the optional 
argument CONTEXT (if CONTEXT is an object of the same class); otherwise a brand 
new object is used.  Only properties recognized by CGI::Portable are set in 
this object; others are not touched.

=cut

######################################################################

sub make_new_context {
	my ($self, $context) = @_;
	ref($context) eq ref($self) or $context = bless( {}, ref($self) );

	$context->{$KEY_IS_DEBUG} = $self->{$KEY_IS_DEBUG};
	$context->{$KEY_ERRORS} = [];
	$context->{$KEY_FILE_PATH} = $self->{$KEY_FILE_PATH}->clone();
	$context->{$KEY_PREFS} = {%{$self->{$KEY_PREFS}}};

	$context->{$KEY_UI_PATH} = $self->{$KEY_UI_PATH}->clone();
	$context->{$KEY_UI_QUER} = $self->{$KEY_UI_QUER}->clone();
	$context->{$KEY_UI_POST} = $self->{$KEY_UI_POST}->clone();
	$context->{$KEY_UI_COOK} = $self->{$KEY_UI_COOK}->clone();

	$context->{$KEY_URL_BASE} = $self->{$KEY_URL_BASE};
	$context->{$KEY_URL_PATH} = $self->{$KEY_URL_PATH}->clone();
	$context->{$KEY_URL_QUER} = $self->{$KEY_URL_QUER}->clone();
	$context->{$KEY_URL_PIPI} = $self->{$KEY_URL_PIPI};
	$context->{$KEY_URL_PIQU} = $self->{$KEY_URL_PIQU};
	$context->{$KEY_URL_PQPN} = $self->{$KEY_URL_PQPN};

	$context->{$KEY_PAGE_TITL} = undef;
	$context->{$KEY_PAGE_AUTH} = undef;
	$context->{$KEY_PAGE_META} = {};
	$context->{$KEY_PAGE_CSSR} = [];
	$context->{$KEY_PAGE_CSSC} = [];
	$context->{$KEY_PAGE_HEAD} = [];
	$context->{$KEY_PAGE_BATR} = {};
	$context->{$KEY_PAGE_BODY} = [];

	$context->{$KEY_HTTP_STAT} = '200 OK';
	$context->{$KEY_HTTP_COTY} = 'text/html';
	$context->{$KEY_HTTP_REDI} = undef;
	$context->{$KEY_HTTP_COOK} = [];
	$context->{$KEY_HTTP_HEAD} = {};
	$context->{$KEY_HTTP_BODY} = undef;
	$context->{$KEY_HTTP_BINA} = undef;

	$context->{$KEY_PREF_APIT} = $self->{$KEY_PREF_APIT};
	$context->{$KEY_PREF_MNAM} = $self->{$KEY_PREF_MNAM};
	$context->{$KEY_PREF_MEAD} = $self->{$KEY_PREF_MEAD};
	$context->{$KEY_PREF_MESP} = $self->{$KEY_PREF_MESP};
	$context->{$KEY_PREF_SMTP} = $self->{$KEY_PREF_SMTP};
	$context->{$KEY_PREF_TIME} = $self->{$KEY_PREF_TIME};

	$context->{$KEY_MISC_OBJECTS} = $self->{$KEY_MISC_OBJECTS};  # copy hash ref

	return( $context );
}

######################################################################

=head2 take_context_output( CONTEXT[, APPEND_LISTS[, SKIP_SCALARS]] )

This method takes another CGI::Portable (or subclass) object as its CONTEXT
argument and copies some of its properties to this object, potentially
overwriting any versions already in this object.  If CONTEXT is not a valid
CGI::Portable (or subclass) object then this method returns without changing
anything. The properties that get copied are the "output" properties that
presumably need to work their way back to the user. Specifically, what does get
copied is: error messages, html page components, and http response components.
What does not get copied is: debug state, file path, preferences, all types of
user input, the url constructor properties, and misc objects. In other words,
this method copies everything that make_new_context() did not. If the optional
boolean argument APPEND_LISTS is true then any list-type properties, including
arrays and hashes, get appended to the existing values where possible rather than
just replacing them.  In the case of hashes, however, keys with the same names
are still replaced.  If the optional boolean argument SKIP_SCALARS is true then
scalar properties are not copied over; otherwise they will always replace any
that are in this object already.

=cut

######################################################################

sub take_context_output {
	my ($self, $context, $append_lists, $skip_scalars) = @_;
	UNIVERSAL::isa( $context, 'CGI::Portable' ) or return( 0 );

	unless( $skip_scalars ) {
		$self->{$KEY_PAGE_TITL} = $context->{$KEY_PAGE_TITL};
		$self->{$KEY_PAGE_AUTH} = $context->{$KEY_PAGE_AUTH};
		$self->{$KEY_HTTP_STAT} = $context->{$KEY_HTTP_STAT};
		$self->{$KEY_HTTP_COTY} = $context->{$KEY_HTTP_COTY};
		$self->{$KEY_HTTP_REDI} = $context->{$KEY_HTTP_REDI};
		$self->{$KEY_HTTP_BODY} = $context->{$KEY_HTTP_BODY};
		$self->{$KEY_HTTP_BINA} = $context->{$KEY_HTTP_BINA};
	}
	if( $append_lists ) {
		push( @{$self->{$KEY_ERRORS}}, @{$self->{$KEY_ERRORS}} );
		push( @{$self->{$KEY_PAGE_CSSR}}, @{$context->{$KEY_PAGE_CSSR}} );
		push( @{$self->{$KEY_PAGE_CSSC}}, @{$context->{$KEY_PAGE_CSSC}} );
		push( @{$self->{$KEY_PAGE_HEAD}}, @{$context->{$KEY_PAGE_HEAD}} );
		push( @{$self->{$KEY_PAGE_BODY}}, @{$context->{$KEY_PAGE_BODY}} );
		push( @{$self->{$KEY_HTTP_COOK}}, 
			map { $_->clone() } @{$context->{$KEY_HTTP_COOK}} );

		@{$self->{$KEY_PAGE_META}}{keys %{$context->{$KEY_PAGE_META}}} = 
			values %{$context->{$KEY_PAGE_META}};
		@{$self->{$KEY_PAGE_BATR}}{keys %{$context->{$KEY_PAGE_BATR}}} = 
			values %{$context->{$KEY_PAGE_BATR}};
		@{$self->{$KEY_HTTP_HEAD}}{keys %{$context->{$KEY_HTTP_HEAD}}} = 
			values %{$context->{$KEY_HTTP_HEAD}};

	} else {
		$self->{$KEY_ERRORS} = [@{$self->{$KEY_ERRORS}}];
		$self->{$KEY_PAGE_CSSR} = [@{$context->{$KEY_PAGE_CSSR}}];
		$self->{$KEY_PAGE_CSSC} = [@{$context->{$KEY_PAGE_CSSC}}];
		$self->{$KEY_PAGE_HEAD} = [@{$context->{$KEY_PAGE_HEAD}}];
		$self->{$KEY_PAGE_BODY} = [@{$context->{$KEY_PAGE_BODY}}];
		$self->{$KEY_HTTP_COOK} = 
			[map { $_->clone() } @{$context->{$KEY_HTTP_COOK}}];

		$self->{$KEY_PAGE_META} = {%{$context->{$KEY_PAGE_META}}};
		$self->{$KEY_PAGE_BATR} = {%{$context->{$KEY_PAGE_BATR}}};
		$self->{$KEY_HTTP_HEAD} = {%{$context->{$KEY_HTTP_HEAD}}};
	}
}

######################################################################

=head2 call_component( COMP_NAME )

This method can be used by one component to invoke another.  For this to work,
the called component needs to be a Perl 5 module with a method called main(). The
argument COMP_NAME is a string containing the name of the module to be invoked.
This method will first "require [COMP_NAME]" and then invoke its dispatch method
with a "[COMP_NAME]->main()".  These statements are wrapped in an "eval" block
and if there was a compile or runtime failure then this method will log an error
message like "can't use module '[COMP_NAME]': $@" and also set the output page 
to be an error screen using that.  So regardless of whether the component worked 
or not, you can simply print the output page the same way.  The call_component() 
method will pass a reference to the CGI::Portable object it is invoked from as an
argument to the main() method of the called module.  If you want the called
component to get a different CGI::Portable object then you will need to
create it in your caller using make_new_context() or new() or clone().  
Anticipating that your component would fail because of it, this method will 
abort with an error screen prior to any "require" if there are errors already 
logged and unresolved.  Any errors existing now were probably set by 
set_prefs(), meaning that the component would be missing its config data were it 
started up.  This method will return 0 upon making an error screen; otherwise, 
it will return 1 if everything worked.  Since this method calls add_no_error() 
upon making the error screen, you should pay attention to its return value if 
you want to make a custom screen instead (so you know when to).

=cut

######################################################################

sub call_component {
	my ($self, $comp_name) = @_;
	if( $self->get_error() ) {
		$self->_make_call_component_error_page( $comp_name );
		return( 0 );
	}
	eval {
		# "require $comp_name;" yields can't find module in @INC error in 5.004
		eval "require $comp_name;"; $@ and die;
		$comp_name->main( $self );
	};
	if( $@ ) {
		$self->add_error( "can't use module '$comp_name': $@" );
		$self->_make_call_component_error_page( $comp_name );
		return( 0 );
	}
	return( 1 );
}

# _make_call_component_error_page( COMP_NAME )
# This private method is used by call_component() to make error screens in 
# situations where there is a failure calling an application component.  
# The main situation in question involves the component module failing to 
# compile or it having a run-time death.  It can also be used when there is 
# nothing wrong with the component itself, but there was a failure in getting 
# preferences for it ahead of time.  This method assumes that the details of 
# the particular error will be returned by get_error() when it is called.  
# The scalar argument COMP_NAME is the name of the module that call_component 
# was trying to or would have been using.  The intent of this method is to 
# save the parent component or thin program config shell from having to compose 
# an error screen for the user by itself, which is often repedative.  The parent 
# module can simply take back the context result page as it always does, which 
# either contains successful output of the component or result of this method.

sub _make_call_component_error_page {
	my ($self, $comp_name) = @_;
	$self->page_title( 'Error Getting Screen' );

	$self->set_page_body( <<__endquote );
<H2 ALIGN="center">@{[$self->page_title()]}</H2>

<P>I'm sorry, but an error occurred while getting the requested screen.  
We were unable to use the application component that was in charge of 
producing the screen content, named '$comp_name'.

<P>This should be temporary, the result of a transient server problem or an 
update being performed at the moment.  Click @{[$self->recall_html('here')]} 
to automatically try again.  If the problem persists, please try again later, 
or send an @{[$self->maintainer_email_html('e-mail')]} message about the 
problem, so it can be fixed.</P>

<P>Detail: @{[$self->get_error()]}</P>
__endquote

	$self->add_no_error();
}

######################################################################

=head1 METHODS FOR SEARCH AND REPLACE

These methods handle miscellaneous functionality that may be useful.

=head2 search_and_replace_page_body( DO_THIS )

This method performs a customizable search-and-replace of this object's "page
body" property.  The argument DO_THIS is a hash ref whose keys are tokens to look
for and the corresponding values are what to replace the tokens with.  Tokens can
be any Perl 5 regular expression and they are applied using
"s/[find]/[replace]/g".  Perl will automatically throw an exception if your
regular expressions don't compile, so you should check them for validity before
use.  If DO_THIS is not a valid hash ref then this method returns without 
changing anything.

=cut

######################################################################

sub search_and_replace_page_body {
	my ($self, $do_this) = @_;
	ref( $do_this ) eq 'HASH' or return( undef );
	my $page_body = join( '', @{$self->{$KEY_PAGE_BODY}} );
	foreach my $find_val (keys %{$do_this}) {
		my $replace_val = $do_this->{$find_val};
		$page_body =~ s/$find_val/$replace_val/g;
	}
	$self->{$KEY_PAGE_BODY} = [$page_body];
}

######################################################################

=head2 search_and_replace_url_path_tokens([ TOKEN ])

This method performs a specialized search-and-replace of this object's "page
body" property.  The nature of this search and replace allows you to to embed 
"url paths" in static portions of your application, such as data files, and then 
replace them with complete self-referencing urls that go to the application 
screen that each url path corresponds to.  How it works is that your data files 
are formatted like '<A HREF="__url_path__=/pics/green">green pics</A>' or 
'<A HREF="__url_path__=../texts">texts page</A>' or 
'<A HREF="__url_path__=/jump&url=http://www.cpan.org">CPAN</A>' and the scalar 
argument TOKEN is equal to '__url_path__' (that is its default value also).  
This method will search for text like in the above formats, specifically the parts between the double-quotes, and substitute in self-referencing urls like 
'<A HREF="http://www.aardvark.net/it.pl/pics/green">green pics</A>' or 
'<A HREF="http://www.aardvark.net/it.pl/jump?url=http://www.cpan.org">CPAN</A>'.  
New urls are constructed in a similar fashion to what url_as_string() makes, and 
incorporates your existing url base, query string, path location setting, and so
on.  Any query string you provide in the source text is added to the url query 
in the output.  This specialized search and replace can not be done with 
search_and_replace_page_body() since that would only replace the '__url_path__' 
part and leave the rest.  The regular expression that is searched for looks 
sort of like /"TOKEN=([^&^"]*)&?(.*?)"/.

=cut

######################################################################

sub search_and_replace_url_path_tokens {
	my ($self, $token) = @_;
	$token ||= '__url_path__';
	my $page_body = join( '', @{$self->{$KEY_PAGE_BODY}} );

	my $_ple = $self->url_base().($self->url_path_is_in_query() ? 
		'?'.$self->url_path_query_param_name().'=' : '');
	my $_pri = $self->url_path_is_in_query() ? '&' : '?';
	my $_que = $self->url_query_string();
	$_que and $_que = "&$_que";
	$page_body =~ s/"$token=([^&^"]*)&?(.*?)"/"$_ple\1$_pri\2$_que"/g;

	$self->{$KEY_PAGE_BODY} = [$page_body];
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

perl(1), File::VirtualPath, HTML::EasyTags, Data::MultiValuedHash, 
CGI::MultiValuedHash, mod_perl, Apache, HTTP::Headers, CGI::Cookie, 
CGI::WPM::SimpleUserIO, CGI::WPM::*, HTML::FormTemplate, CGI, CGI::Screen, 
CGI::MxScreen, CGI::Application, CGI::BuildPage, CGI::Response, HTML::Mason.

=cut

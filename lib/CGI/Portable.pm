=head1 NAME

CGI::Portable - Framework for server-generic web apps

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
use vars qw($VERSION @ISA);
$VERSION = '0.46';

######################################################################

=head1 DEPENDENCIES

=head2 Perl Version

	5.004

=head2 Standard Modules

	I<none>

=head2 Nonstandard Modules

	CGI::Portable::Files 0.46
	CGI::Portable::Request 0.46
	CGI::Portable::Response 0.46

=cut

######################################################################

use CGI::Portable::Files 0.46;
use CGI::Portable::Request 0.46;
use CGI::Portable::Response 0.46;
@ISA = qw( CGI::Portable::Files CGI::Portable::Request CGI::Portable::Response );

######################################################################

=head1 SYNOPSIS

=head2 Content of thin shell "startup_cgi.pl" for CGI or Apache::Registry env:

	#!/usr/bin/perl
	use strict;

	require CGI::Portable;
	my $globals = CGI::Portable->new();

	use Cwd;
	$globals->file_path_root( cwd() );  # let us default to current working directory
	$globals->file_path_delimiter( $^O=~/Mac/i ? ":" : $^O=~/Win/i ? "\\" : "/" );

	$globals->set_prefs( 'config.pl' );
	$globals->current_user_path_level( 1 );

	require CGI::Portable::AdapterCGI;
	my $io = CGI::Portable::AdapterCGI->new();

	$io->fetch_user_input( $globals );
	$globals->call_component( 'Aardvark' );
	$io->send_user_output( $globals );

	1;

=head2 Content of thin shell "startup_socket.pl" for IO::Socket::INET:

	#!/usr/bin/perl
	use strict;

	print "[Server $0 starting up]\n";

	require CGI::Portable;
	my $globals = CGI::Portable->new();

	use Cwd;
	$globals->file_path_root( cwd() );  # let us default to current working directory
	$globals->file_path_delimiter( $^O=~/Mac/i ? ":" : $^O=~/Win/i ? "\\" : "/" );

	$globals->set_prefs( 'config.pl' );
	$globals->current_user_path_level( 1 );

	require CGI::Portable::AdapterSocket;
	my $io = CGI::Portable::AdapterSocket->new();

	use IO::Socket;
	my $server = IO::Socket::INET->new(
		Listen    => SOMAXCONN,
		LocalAddr => '127.0.0.1',
		LocalPort => 1984,
		Proto     => 'tcp'
	);
	die "[Error: can't setup server $0]" unless $server;

	print "[Server $0 accepting clients]\n";

	while( my $client = $server->accept() ) {
		printf "%s: [Connect from %s]\n", scalar localtime, $client->peerhost;

		my $content = $globals->make_new_context();

		$io->fetch_user_input( $content, $client );
		$content->call_component( 'Aardvark' );
		$io->send_user_output( $content, $client );

		close $client;

		printf "%s http://%s:%s%s %s\n", $content->request_method, 
			$content->server_domain, $content->server_port, 
			$content->user_path_string, $content->http_status_code;
	}

	1;

=head2 Content of settings file "config.pl"

	my $rh_prefs = {
		title => 'Welcome to Aardvark',
		credits => '<p>This program copyright 2001 Darren Duncan.</p>',
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
							rows => 2,
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

I<This module acts sort of like CGI::Portable::AppMultiScreen.>

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
			$globals->set_page_body( "<p>Please choose a screen to view.</p>" );
			foreach my $key (keys %{$rh_screens}) {
				my $label = $rh_screens->{$key}->{link};
				my $url = $globals->url_as_string( $key );
				$globals->append_page_body( "<br /><a href=\"$url\">$label</a>" );
			}
		}
		
		$globals->page_title( $globals->pref( 'title' ) );
		$globals->prepend_page_body( "<h1>".$globals->page_title()."</h1>\n" );
		$globals->append_page_body( $globals->pref( 'credits' ) );
	}

	1;

=head2 Content of component module "Tiger.pm"

I<This module acts sort of like DemoMailForm without the emailing.>

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
			'<h1>Here Are Some Questions</h1>',
			$form->make_html_input_form( 1 ),
			'<hr />',
			'<h1>Answers From Last Time If Any</h1>',
			$form->new_form() ? '' : $form->make_html_input_echo( 1 ),
		);
	}

	1;

=head2 Content of component module "Owl.pm"

I<This module acts sort of like DemoRedirect.>

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

I<This module acts sort of like DemoStatic.>

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
	<p>Food: @{[$globals->pref( 'food' )]}
	<br />Color: @{[$globals->pref( 'color' )]}
	<br />Size: @{[$globals->pref( 'size' )]}</p>
	<p>Now let's look at some files; take your pick:
	__endquote
		$globals->navigate_url_path( $globals->pref( 'file_reader' ) );
		foreach my $frag (@{$globals->pref( 'files' )}) {
			my $url = $globals->url_as_string( $frag );
			$globals->append_page_body( "<br /><a href=\"$url\">$frag</a>" );
		}
		$globals->append_page_body( "</p>" );
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
easier for you to divide your application into autonomous components, each of
which acts like it is its own application core with user input and instance
config data provided to it and a recepticle for its user output provided. This
module would be an interface between the components.

This class inherits most of its functionality from four other modules that were
created with that intent, although each can be used independantly as well:

	- CGI::Portable::Errors
	- CGI::Portable::Files
	- CGI::Portable::Request
	- CGI::Portable::Response

Each module has complete POD for functionality it implements, with conceptual 
overviews and method descriptions.  Please read them in order to have the best 
understanding of what CGI::Portable can do.

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
separate whereas most of the others use CGI.pm which combines them together; more
differences.

=head1 YES, THIS MODULE DOES IMAGES

Just in case you were thinking that this module does plain html only and is no 
good for image-making applications, let me remind you that, yes, CGI::Portable 
can map urls to, store, and output any type of file, including pictures and other 
binary types.

To illustrate this, I have provided the "image" demo consisting of an html page 
containing a PNG graphic, both of which are generated by the same script.  (You 
will need to have GD installed to see the picture, though.)  

Besides that, this module has explicit support for the likes of cascading style 
sheets (css) and complete multi-frame documents in one script as well, which are 
normally just used in graphical environments.

So while a few critics have pointed out the fact that my own websites, which use 
this module, don't have graphics, then that is purely my own preference as a way 
to make them load faster and use less bandwidth, not due to any lack of the 
ability to use pictures.

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

=cut

######################################################################

# Names of properties for objects of this class are declared here:
my $KEY_IS_DEBUG = 'is_debug';  # boolean - a flag to say we are debugging

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

=head2 initialize([ FILE_ROOT[, FILE_DELIM[, PREFS]] ])

This method is used by B<new()> to set the initial properties of objects that it
creates.  The optional 3 arguments are used in turn to set the properties 
accessed by these methods: file_path_root(), file_path_delimiter(), set_prefs().

=head2 clone([ CLONE ])

This method initializes a new object to have all of the same properties of the
current object and returns it.  This new object can be provided in the optional
argument CLONE (if CLONE is an object of the same class as the current object);
otherwise, a brand new object of the current class is used.  Only object
properties recognized by CGI::Portable are set in the clone; other
properties are not changed.

=cut

######################################################################

sub new {
	my $class = shift( @_ );
	my $self = bless( {}, ref($class) || $class );
	$self->initialize( @_ );
	return( $self );
}

sub initialize {
	my ($self, $file_root, $file_delim, $prefs) = @_;

	$self->CGI::Portable::Files::initialize();
	$self->CGI::Portable::Request::initialize();
	$self->CGI::Portable::Response::initialize();

	$self->{$KEY_IS_DEBUG} = undef;

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

sub clone {
	my ($self, $clone) = @_;
	ref($clone) eq ref($self) or $clone = bless( {}, ref($self) );

	$clone = $self->CGI::Portable::Files::clone( $clone );
	$clone = $self->CGI::Portable::Request::clone( $clone );
	$clone = $self->CGI::Portable::Response::clone( $clone );

	$clone->{$KEY_IS_DEBUG} = $self->{$KEY_IS_DEBUG};

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

=head1 METHODS FOR CONTEXT SWITCHING

These methods are designed to facilitate easy modularity of your application 
into multiple components by providing context switching functions for the parent 
component in a relationship.  While you could still use this class effectively 
without using them, they are available for your convenience.

=head2 make_new_context([ CONTEXT ])

This method initializes a new object of the current class and returns it.  This
new object has some of the current object's properties, namely the "input"
properties, but lacks others, namely the "output" properties; the latter are
initialized to default values instead.  As with clone(), the new object can be
provided in the optional argument CONTEXT (if CONTEXT is an object of the same
class); otherwise a brand new object is used.  Only properties recognized by
CGI::Portable are set in this object; others are not touched.

=cut

######################################################################

sub make_new_context {
	my ($self, $context) = @_;
	ref($context) eq ref($self) or $context = bless( {}, ref($self) );

	$context = $self->CGI::Portable::Files::make_new_context( $context );
	$context = $self->CGI::Portable::Request::make_new_context( $context );
	$context = $self->CGI::Portable::Response::make_new_context( $context );

	$context->{$KEY_IS_DEBUG} = $self->{$KEY_IS_DEBUG};

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

=head2 take_context_output( CONTEXT[, LEAVE_SCALARS[, REPLACE_LISTS]] )

This method takes another CGI::Portable (or subclass) object as its
CONTEXT argument and copies some of its properties to this object, potentially
overwriting any versions already in this object.  If CONTEXT is not a valid
CGI::Portable (or subclass) object then this method returns without
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

sub take_context_output {
	my ($self, $context, $leave_scalars, $replace_lists) = @_;
	UNIVERSAL::isa( $context, 'CGI::Portable' ) or return( 0 );

	$self->CGI::Portable::Files::take_context_output( 
		$context, $leave_scalars, $replace_lists );
	$self->CGI::Portable::Request::take_context_output( 
		$context, $leave_scalars, $replace_lists );
	$self->CGI::Portable::Response::take_context_output( 
		$context, $leave_scalars, $replace_lists );
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
<h1>@{[$self->page_title()]}</h1>

<p>I'm sorry, but an error occurred while getting the requested screen.  
We were unable to use the application component that was in charge of 
producing the screen content, named '$comp_name'.</p>

<p>This should be temporary, the result of a transient server problem or an 
update being performed at the moment.  Click @{[$self->recall_html('here')]} 
to automatically try again.  If the problem persists, please try again later, 
or send an @{[$self->maintainer_email_html('e-mail')]} message about the 
problem, so it can be fixed.</p>

<p>Detail: @{[$self->get_error()]}</p>
__endquote

	$self->add_no_error();
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

=head1 METHODS FOR SEARCH AND REPLACE

This method supplements the page_search_and_replace() method in 
CGI::Portable::Response with a more proprietary solution.

=head2 search_and_replace_url_path_tokens([ TOKEN ])

This method performs a specialized search-and-replace of this object's "page
body" property.  The nature of this search and replace allows you to to embed 
"url paths" in static portions of your application, such as data files, and then 
replace them with complete self-referencing urls that go to the application 
screen that each url path corresponds to.  How it works is that your data files 
are formatted like '<a href="__url_path__=/pics/green">green pics</a>' or 
'<a href="__url_path__=../texts">texts page</a>' or 
'<a href="__url_path__=/jump&url=http://www.cpan.org">CPAN</a>' and the scalar 
argument TOKEN is equal to '__url_path__' (that is its default value also).  
This method will search for text like in the above formats, specifically the parts between the double-quotes, and substitute in self-referencing urls like 
'<a href="http://www.aardvark.net/it.pl/pics/green">green pics</a>' or 
'<a href="http://www.aardvark.net/it.pl/jump?url=http://www.cpan.org">CPAN</a>'.  
New urls are constructed in a similar fashion to what url_as_string() makes, and 
incorporates your existing url base, query string, and so
on.  Any query string you provide in the source text is added to the url query 
in the output.  This specialized search and replace can not be done with 
page_search_and_replace() since that would only replace the '__url_path__' 
part and leave the rest.  The regular expression that is searched for looks 
sort of like /"TOKEN=([^&^"]*)&?(.*?)"/.

=cut

######################################################################

sub search_and_replace_url_path_tokens {
	my ($self, $token) = @_;
	$token ||= '__url_path__';
	my $ra_page_body = $self->get_page_body_ref();
	my $body = join( '', @{$ra_page_body} );

	my $_ple = $self->url_base(); # SIMPLIFIED THIS 0-45
	my $_pri = '?'; # SIMPLIFIED THIS 0-45
	my $_que = $self->url_query_string();
	$_que and $_que = "&$_que";
	$body =~ s/"$token=([^&^"]*)&?(.*?)"/"$_ple\1$_pri\2$_que"/g;
	$body =~ s/\?&/\?/g; # ADDED THIS LINE 0-43
	$body =~ s/\?"/"/g; # ADDED THIS LINE 0-46

	@{$ra_page_body} = ($body);
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
		"<a href=\"@{[$self->url_as_string( $path )]}\">$label</a> ($addy)" : 
		"<a href=\"mailto:$addy\">$label</a> ($addy)" );
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

perl(1), CGI::Portable::*, mod_perl, Apache, Demo*, 
HTML::FormTemplate, CGI, CGI::Screen, CGI::MxScreen, 
CGI::Application, CGI::BuildPage, CGI::Response, HTML::Mason.

=cut

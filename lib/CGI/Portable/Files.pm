=head1 NAME

CGI::Portable::Files - Manages virtual file system and app instance config files

=cut

######################################################################

package CGI::Portable::Files;
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

	File::VirtualPath 1.0
	CGI::Portable::Errors 0.46 (a superclass)

=cut

######################################################################

use File::VirtualPath 1.0;
use CGI::Portable::Errors 0.46;
@ISA = qw( CGI::Portable::Errors );

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

This class implements two distinct but closely related "input" properties, the 
"file path", and the "preferences", which manage a virtual file system and 
application instance config data respectively.  Please see VIRTUAL FILE SYSTEM 
OVERVIEW and INSTANCE PREFERENCES OVERVIEW below for a conceptual explanation of 
what these are for and how to use them.  

This class also subclasses CGI::Portable::Errors, and so its "error list" 
property (output) and related methods are available for use through this class.

=head1 VIRTUAL FILE SYSTEM OVERVIEW

This class implements methods that manage a "file path" property, which is
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

=head1 INSTANCE PREFERENCES OVERVIEW

This class implements methods that manage a "preferences" property, which 
is designed to facilitate easy access to your application instance settings.
The "preferences" is a hierarchical data structure which has a hash as its root 
and can be arbitrarily complex from that point on.  A hash is used so that any 
settings can be accessed by name; the hierarchical nature comes from any 
setting values that are references to non-scalar values, or resolve to such.

CGI::Portable::Files makes it easy for your preferences structure to scale across 
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

=cut

######################################################################

# Names of properties for objects of this class are declared here:
my $KEY_FILE_PATH = 'file_path';  # FVP - tracks filesystem loc of our files
my $KEY_PREFS = 'prefs';  # hash - tracks our current file-based preferences

######################################################################

=head1 SYNTAX

This class does not export any functions or methods, so you need to call them
using object notation.  This means using B<Class-E<gt>function()> for functions
and B<$object-E<gt>method()> for methods.  If you are inheriting this class for
your own modules, then that often means something like B<$self-E<gt>method()>. 

=head1 CONSTRUCTOR FUNCTIONS AND METHODS AND CONTEXT SWITCHING

These functions and methods are involved in making new CGI::Portable::Files
objects, except the last one which combines two existing ones.  All five of them 
are present in both CGI::Portable and other classes designed to be inherited by 
it, including this one, because they implement its functionality.

=head2 new()

This function creates a new CGI::Portable::Files (or subclass) object and
returns it.

=head2 initialize()

This method is used by B<new()> to set the initial properties of objects that it
creates.

=head2 clone([ CLONE ])

This method initializes a new object to have all of the same properties of the
current object and returns it.  This new object can be provided in the optional
argument CLONE (if CLONE is an object of the same class as the current object);
otherwise, a brand new object of the current class is used.  Only object
properties recognized by CGI::Portable::Files are set in the clone; other
properties are not changed.

=head2 make_new_context([ CONTEXT ])

This method initializes a new object of the current class and returns it.  This
new object has some of the current object's properties, namely the "input"
properties, but lacks others, namely the "output" properties; the latter are
initialized to default values instead.  As with clone(), the new object can be
provided in the optional argument CONTEXT (if CONTEXT is an object of the same
class); otherwise a brand new object is used.  Only properties recognized by
CGI::Portable::Files are set in this object; others are not touched.

=head2 take_context_output( CONTEXT[, LEAVE_SCALARS[, REPLACE_LISTS]] )

This method takes another CGI::Portable::Files (or subclass) object as its
CONTEXT argument and copies some of its properties to this object, potentially
overwriting any versions already in this object.  If CONTEXT is not a valid
CGI::Portable::Files (or subclass) object then this method returns without
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

# sub new {}
# We simply inherit this method and add no new functionality ourself.

sub initialize {
	my ($self) = @_;

	$self->SUPER::initialize();

	$self->{$KEY_FILE_PATH} = File::VirtualPath->new();
	$self->{$KEY_PREFS} = {};
}

sub clone {
	my ($self, $clone) = @_;
	ref($clone) eq ref($self) or $clone = bless( {}, ref($self) );

	$clone = $self->SUPER::clone( $clone );

	$clone->{$KEY_FILE_PATH} = $self->{$KEY_FILE_PATH}->clone();
	$clone->{$KEY_PREFS} = {%{$self->{$KEY_PREFS}}};

	return( $clone );
}

sub make_new_context {
	my ($self, $context) = @_;
	ref($context) eq ref($self) or $context = bless( {}, ref($self) );

	$context = $self->SUPER::make_new_context( $context );

	$context->{$KEY_FILE_PATH} = $self->{$KEY_FILE_PATH}->clone();
	$context->{$KEY_PREFS} = {%{$self->{$KEY_PREFS}}};

	return( $context );
}

# sub take_context_output {}
# We simply inherit this method and add no new functionality ourself.
# All of our own added properties are of the input variety.

######################################################################

=head1 METHODS FOR THE VIRTUAL FILE SYSTEM

These methods are accessors for the "file path" property of this object, which is
designed to facilitate easy portability of your application across multiple file
systems or across different locations in the same file system.  See the 
DESCRIPTION for more details.

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

=head1 METHODS FOR INSTANCE PREFERENCES

These methods are accessors for the "preferences" property of this object, which 
is designed to facilitate easy access to your application instance settings.  
See the DESCRIPTION for more details.

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

perl(1), File::VirtualPath, CGI::Portable::Errors, CGI::Portable.

=cut

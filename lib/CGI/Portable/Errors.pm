=head1 NAME

CGI::Portable::Errors - Manages error list for operations

=cut

######################################################################

package CGI::Portable::Errors;
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

	I<none>

=head1 SYNOPSIS

I<See CGI::Portable, which is a subclass of this.>

=head1 DESCRIPTION

This class is designed to be inherited by CGI::Portable and implements some of 
that module's functionality; however, this class can also be used by itself.  
The split of functionality between several modules is intended to emphasize the 
fact that CGI::Portable is doing several tasks in parallel that are related but 
distinct, so you have more flexability to use what you need and not carry around 
what you don't use.  Each module has the POD for all methods it implements.

This class implements methods that manage an "error list" property, 
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

=cut

######################################################################

# Names of properties for objects of this class are declared here:
my $KEY_ERRORS = 'errors';  # array - a list of short error messages

######################################################################

=head1 SYNTAX

This class does not export any functions or methods, so you need to call them
using object notation.  This means using B<Class-E<gt>function()> for functions
and B<$object-E<gt>method()> for methods.  If you are inheriting this class for
your own modules, then that often means something like B<$self-E<gt>method()>. 

=head1 CONSTRUCTOR FUNCTIONS AND METHODS AND CONTEXT SWITCHING

These functions and methods are involved in making new CGI::Portable::Errors
objects, except the last one which combines two existing ones.  All five of them 
are present in both CGI::Portable and other classes designed to be inherited by 
it, including this one, because they implement its functionality.

=head2 new()

This function creates a new CGI::Portable::Errors (or subclass) object and
returns it.

=head2 initialize()

This method is used by B<new()> to set the initial properties of objects that it
creates.

=head2 clone([ CLONE ])

This method initializes a new object to have all of the same properties of the
current object and returns it.  This new object can be provided in the optional
argument CLONE (if CLONE is an object of the same class as the current object);
otherwise, a brand new object of the current class is used.  Only object
properties recognized by CGI::Portable::Errors are set in the clone; other
properties are not changed.

=head2 make_new_context([ CONTEXT ])

This method initializes a new object of the current class and returns it.  This
new object has some of the current object's properties, namely the "input"
properties, but lacks others, namely the "output" properties; the latter are
initialized to default values instead.  As with clone(), the new object can be
provided in the optional argument CONTEXT (if CONTEXT is an object of the same
class); otherwise a brand new object is used.  Only properties recognized by
CGI::Portable::Errors are set in this object; others are not touched.

=head2 take_context_output( CONTEXT[, LEAVE_SCALARS[, REPLACE_LISTS]] )

This method takes another CGI::Portable::Errors (or subclass) object as its
CONTEXT argument and copies some of its properties to this object, potentially
overwriting any versions already in this object.  If CONTEXT is not a valid
CGI::Portable::Errors (or subclass) object then this method returns without
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

	$self->{$KEY_ERRORS} = [];
}

sub clone {
	my ($self, $clone) = @_;
	ref($clone) eq ref($self) or $clone = bless( {}, ref($self) );

	$clone->{$KEY_ERRORS} = [@{$self->{$KEY_ERRORS}}];

	return( $clone );
}

sub make_new_context {
	my ($self, $context) = @_;
	ref($context) eq ref($self) or $context = bless( {}, ref($self) );

	$context->{$KEY_ERRORS} = [];

	return( $context );
}

sub take_context_output {
	my ($self, $context, $leave_scalars, $replace_lists) = @_;
	UNIVERSAL::isa( $context, 'CGI::Portable::Errors' ) or return( 0 );

	if( $replace_lists ) {
		@{$context->{$KEY_ERRORS}} and 
			$self->{$KEY_ERRORS} = [@{$context->{$KEY_ERRORS}}];
	} else {
		push( @{$self->{$KEY_ERRORS}}, @{$context->{$KEY_ERRORS}} );
	}
}

######################################################################

=head1 METHODS FOR ERROR MESSAGES

These methods are accessors for the "error list" property of this object, 
which is designed to accumulate any error strings that should be printed to the 
program's error log or shown to the user before the program exits.  See the 
DESCRIPTION for more details.

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

perl(1), CGI::Portable::Files, CGI::Portable.

=cut

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..1\n"; }
END {print "not ok 1\n" unless $loaded;}
use CGI::Portable::Errors 0.43;
use CGI::Portable::Files 0.43;
use CGI::Portable::Request 0.43;
use CGI::Portable::Response 0.43;
use CGI::Portable 0.43;
use CGI::Portable::AdapterCGI 0.43;
use CGI::Portable::AdapterSocket 0.43;
use CGI::WPM::Base 0.42;
use CGI::WPM::MultiPage 0.4102;
use CGI::WPM::Static 0.4101;
use CGI::WPM::MailForm 0.43;
use CGI::WPM::GuestBook 0.43;
use CGI::WPM::SegTextDoc 0.4101;
use CGI::WPM::Redirect 0.4101;
use CGI::WPM::Usage 0.43;
use CGI::WPM::CountFile 0.41;
$loaded = 1;
print "ok 1\n";
use strict;

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

#	* Note that "test.pl" is incomplete; it only tests that this module will 
#	compile but not that the methods work; it is included so that people can use 
#	the Makefile in the standard way during installation.  This file will be 
#	fleshed out when I have the chance.

1;

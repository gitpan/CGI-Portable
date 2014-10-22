#!/usr/bin/perl
use strict;
use warnings;
use lib '/home/darren/perl_lib';

# SmartHouse - A Web-based X10 Device Controller in Perl.
# This demo is based on a college lab assignment.  It doesn't actually 
# control any hardware, but is a simple web interface for such a program 
# should one want to extend it in that manner.  This is meant to show how 
# CGI::Portable can be used in a wide variety of environments, not just 
# ordinary database or web sites.  If you wanted to extend it then you 
# should use modules like ControlX10::CM17, ControlX10::CM11, or 
# Device::SerialPort.  On the other hand, if you want a very complete 
# (and complicated) Perl solution then you can download Bruce Winter's 
# free open-source MisterHouse instead at "http://www.misterhouse.net".

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
$globals->call_component( 'X10' );
$io->send_user_output( $globals );

1;

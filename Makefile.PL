use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
	NAME	=> 'CGI::Portable',
	VERSION => 0.42,
	PREREQ_PM => {
		'File::VirtualPath' => 1.0,
		'HTML::EasyTags' => 1.05,
		'Data::MultiValuedHash' => 1.07,
		'CGI::MultiValuedHash' => 1.07,
		'HTML::FormTemplate' => 2.0,  # for CGI::WPM::* modules only
		'Net::SMTP' => 1,  # I don't know what version; for CGI::WPM::* only
		'Apache' => 1,  # I don't know what version; for WebUserIO under mod_perl
	},
);

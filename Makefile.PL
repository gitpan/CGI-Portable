use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
	NAME	=> 'CGI::Portable',
	VERSION => 0.41,
	PREREQ_PM => {
		'File::VirtualPath' => 1.0,
		'HTML::EasyTags' => 1.04,
		'Data::MultiValuedHash' => 1.07,
		'CGI::MultiValuedHash' => 1.07,
		'HTML::FormTemplate' => 2.0,  # for CGI::WPM::* modules only
	},
);

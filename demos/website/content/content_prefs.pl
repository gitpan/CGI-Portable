my $rh_preferences = { 
	page_header => undef,
	page_footer => <<__endquote,
<P><EM>This site is a simple example of what can be done with CGI::Portable and 
the Dynamic Website Generator collection of Perl 5 modules, copyright (c) 
1999-2001, Darren R. Duncan.</EM></P>
__endquote
	page_css_code => [
		'BODY {background-color: white; background-image: none}'
	],
	vrp_handlers => {
		external => {
			wpm_module => 'CGI::WPM::Redirect',
			wpm_prefs => { http_target => 'external_link_window' },
		},
		frontdoor => {
			wpm_module => 'CGI::WPM::Static',
			wpm_prefs => { filename => 'frontdoor.html' },
		},
		resume => {
			wpm_module => 'CGI::WPM::Static',
			wpm_prefs => { filename => 'resume.html' },
		},
		mysites => {
			wpm_module => 'CGI::WPM::Static',
			wpm_prefs => { filename => 'mysites.html' },
		},
		mailme => {
			wpm_module => 'CGI::WPM::MailForm',
			wpm_prefs => {},
		},
		guestbook => {
			wpm_module => 'CGI::WPM::GuestBook',
			wpm_prefs => {
				fn_messages => 'guestbook_messages.txt',
				custom_fd => 1,
				field_defn => 'guestbook_questions.txt',
				fd_in_seqf => 1,
			},
		},
		links => {
			wpm_module => 'CGI::WPM::Static',
			wpm_prefs => { filename => 'links.html' },
		},
	},
	def_handler => 'frontdoor',
	menu_items => [
		{
			menu_name => 'Front Door',
			menu_path => '',
			is_active => 1,
		}, 1, {
			menu_name => 'Resume',
			menu_path => 'resume',
			is_active => 1,
		}, {
			menu_name => 'Web Sites I Made',
			menu_path => 'mysites',
			is_active => 1,
		}, 1, {
			menu_name => 'E-mail Me',
			menu_path => 'mailme',
			is_active => 1,
		}, {
			menu_name => 'Guest Book',
			menu_path => 'guestbook',
			is_active => 1,
		}, 1, {
			menu_name => 'Other Links',
			menu_path => 'links',
			is_active => 1,
		},
	],
	menu_cols => 4,
	menu_showdiv => 0,
	page_showdiv => 1,
};

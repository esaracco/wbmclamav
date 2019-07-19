#!/usr/bin/perl

# Copyright (C) 2003-2019
# Emmanuel Saracco <emmanuel@esaracco.fr>
#
# GNU GENERAL PUBLIC LICENSE

require './clamav-lib.pl';
&clamav_check_acl ('quarantine_view');
&ReadParse ();

&header($text{'FORM_TITLE'}, '', undef, 1, 0);
print qq(<hr/>\n);

print qq(<h1>$text{'QUARANTINE_VIEWMAIL_PAGE_TITLE'}</h1>\n);
print qq(<p>$text{'QUARANTINE_VIEWMAIL_PAGE_DESCRIPTION'}</p>);

&clamav_print_email ($in{'base'});

print qq(<hr/>);
&footer('quarantine_main.cgi', $text{'RETURN_QUARANTINE_LIST'});

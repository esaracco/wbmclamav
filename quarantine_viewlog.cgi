#!/usr/bin/perl

# Copyright (C) 2003-2019
# Emmanuel Saracco <emmanuel@esaracco.fr>
#
# GNU GENERAL PUBLIC LICENSE

require './clamav-lib.pl';
&clamav_check_acl ('quarantine_view');
&ReadParse ();

&clamav_header ($text{'QUARANTINE_VIEWLOG_PAGE_TITLE'});

print qq(<p>$text{'QUARANTINE_VIEWLOG_PAGE_DESCRIPTION'}</p>);

&clamav_quarantine_print_log ($in{'base'});

print qq(<hr>);
&footer("quarantine_main.cgi", $text{'RETURN_QUARANTINE_LIST'});

#!/usr/bin/perl

# Copyright (C) 2003-2019
# Emmanuel Saracco <emmanuel@esaracco.fr>
#
# GNU GENERAL PUBLIC LICENSE

require './clamav-lib.pl';
&clamav_check_acl ('quarantine_delete');
&ReadParse ();

if (not $in{'next'})
{
  &header($text{'FORM_TITLE'}, "", undef, 1, 0);
  print "<hr>\n";

  print qq(<h1>$text{'QUARANTINE_REMOVE_PAGE_TITLE'}</h1>\n);
  print qq(<p>$text{'QUARANTINE_REMOVE_PAGE_DESCRIPTION'}</p>);

  &clamav_print_email_infos ($in{'base'});
  
  print qq(<form method="POST" action="$scriptname">\n);
  print qq(<input type="hidden" name="todelete" value="$in{'base'}">\n);
  print qq(<p><input type="submit" name="next" value="$text{'DELETE'}"></p>\n);
  print qq(</form>\n);

  print qq(<hr/>);
  &footer ("quarantine_main.cgi", $text{'RETURN_QUARANTINE_LIST'});
}
else
{
  &clamav_remove_email ($in{'todelete'});
  &redirect ("/$module_name/quarantine_main.cgi?removed=0");
}

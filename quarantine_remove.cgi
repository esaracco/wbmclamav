#!/usr/bin/perl

# Copyright (C) 2003-2008
# Emmanuel Saracco <emmanuel@esaracco.fr>
# Easter-eggs <http://www.easter-eggs.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330,
# Boston, MA 02111-1307, USA.

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

  print qq(<hr);
  &footer ("quarantine_main.cgi", $text{'RETURN_QUARANTINE_LIST'});
}
else
{
  &clamav_remove_email ($in{'todelete'});
  &redirect ("/$module_name/quarantine_main.cgi?removed=0");
}

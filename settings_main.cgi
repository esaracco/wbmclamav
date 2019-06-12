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
&clamav_check_acl ('global_settings_view');
&ReadParse ();

# clean temp if first access
if ($ENV{REQUEST_METHOD} eq "GET")
  {&clamav_clean_global_settings_tempfiles ()}
else
  {&clamav_check_acl ('global_settings_write')}

&header($text{'FORM_TITLE'}, "", undef, 1, 0);
print "<hr>\n";

print qq(<h1>$text{'SETTINGS_TITLE'}</h1>);
print qq(<p>$text{'SETTINGS_DESCRIPTION'}</p>);

if ($in{'next'})
{
  $buf = &clamav_save_global_settings (1);
  print qq(<p>);

  if ($buf)
  {
    print "<p>$buf<p>";
  }
  else
  {
    print qq(<p>);
    if (&clamav_is_clamd_alive ())
    {
      print qq(<b>$text{'MSG_SUCCES_APPLY_GLOBAL_SETTINGS'}</b>);
    }
    else
    {
      printf qq(<b>$text{'MSG_ERROR_APPLY_GLOBAL_SETTINGS'}</b>), $config{'clamav_clamav_log'};
    }
  }
}
else
{
  # if there is a item to add
  $add_item_c = $in{'nsclamav_add_key'} if ($in{'nsclamav_add'});
  $add_item_f = $in{'nsfreshclam_add_key'} if ($in{'nsfreshclam_add'});
  
  # if there is a item to delete
  $delete_item_c = &clamav_global_settings_get_delete_item ('clamav');
  $delete_item_f = &clamav_global_settings_get_delete_item ('freshclam');
}

print qq(<form method="POST" action="$scriptname">);

print qq(<h2>$text{'SETTINGS_CLAMAV_TITLE'}</h2>);

&clamav_display_clamav_settings ($add_item_c, $delete_item_c);

print qq(<h2>$text{'SETTINGS_FRESHCLAM_TITLE'}</h2>);

&clamav_display_freshclam_settings ($add_item_f, $delete_item_f);

if (&clamav_get_acl ('global_settings_write') == 1)
{
  print qq(<p><input type="submit" name="next" value="$text{'APPLY'}"></p>);
}

print qq(</form>);

print qq(<hr>);
&footer("", $text{'RETURN_INDEX_MODULE'});

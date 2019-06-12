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
&clamav_check_acl ('database_search_search');
&ReadParse ();

&header($text{'FORM_TITLE'}, "", undef, 1, 0);
print "<hr>\n";

$search = (($in{'search'} and $in{'virus'}) or $in{'all'});

print qq(<h1>$text{'VDB_SEARCH_TITLE'}</h1>);
printf "<p><i>$text{'VDB_SEARCH_VIRUSES_COUNT'}</i> ",
  &clamav_get_db_viruses_count ();
print qq( [<a href="/$module_name/updates_main.cgi">$text{'VDB_SEARCH_UPDATE_DB'}</a>]</p>);
print qq(<p>$text{'VDB_SEARCH_DESCRIPTION'}</p>);

if ($in{'search'} and not $in{'virus'})
{
  print qq(<p><b>$text{'MSG_VIRUS_NAME'}</b></p>);
}

print qq(<form method="POST" action="$scriptname">);

# search string input
print qq(<input type="text" name="virus" value="$in{'virus'}">);

# strict match check box
$checked = ($in{'strict'} eq 'on') ? ' CHECKED' : '';
print qq(<p><input id="strict" type="checkbox" name="strict" value="on"$checked> );
print qq(<label for="strict">$text{'SEARCH_STRICT'}</label>);

# case sensitive check box
$checked = ($in{'case'} eq 'on') ? ' CHECKED' : '';
print qq( <input id="case" type="checkbox" name="case" value="on"$checked> );
print qq(<label for="case">$text{'SEARCH_CASE_SENSITIVE'}</label></p>);

# sort result check box
$checked = ($in{'sort'} eq 'on') ? ' CHECKED' : '';
print qq(<p><input id="sort" type="checkbox" name="sort" value="on"$checked> );
print qq(<label for="sort">$text{'SEARCH_SORT_RESULT'}</label></p>);

print qq(<p><input type="submit" name="search" value="$text{'SEARCH'}"> );
print qq(<input type="submit" name="all" value="$text{'DISPLAY_ALL'}"></p>);

print qq(</form>);

if ($search)
{
  $in{'virus'} = '' if ($in{'all'});

  print qq(<p>);
  &clamav_vdb_search ($in{'virus'}, 
    ($in{'strict'} eq 'on'), ($in{'case'} eq 'on'), ($in{'sort'} eq 'on'));
  print qq(</p>);
}


print qq(<hr>);
&footer("", $text{'RETURN_INDEX_MODULE'});

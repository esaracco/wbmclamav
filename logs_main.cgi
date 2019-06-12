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
&clamav_check_acl ('logs_viewer_view');
&ReadParse ();

&header($text{'FORM_TITLE'}, "", undef, 1, 0);
print "<hr>\n";

print qq(<form method="POST" action="$scriptname">);

print qq(<h1>$text{'LOGS_PAGE_TITLE'}</h1>\n);
print qq(<p>$text{'LOGS_PAGE_DESCRIPTION'}</p>);

print qq($text{'DISPLAY'} );
print qq(<select name="lines">);
printf "<option value=\"0\"%s>%s</option>", 
  (not $in{'lines'}) ? ' SELECTED' : '', $text{'ALL'};
foreach $value (qw(10 20 50 100 150 200 250 300))
{
  printf "<option value=\"%s\"%s>%s</option>", 
    $value, ($in{'lines'} eq $value) ? ' SELECTED' : '', $value;
}
print qq(</select>);

print qq( $text{'LINES_OF'} );

@logs = &clamav_get_logfiles ();
print qq(<select name="logfile">);
foreach $log (@logs)
{
  printf ("<option value=\"%s\"%s>%s</option>",
    $log,
    ($log eq $in{'logfile'}) ? ' SELECTED' : '',
    $log
  );
}
print qq(</select>);
print qq(<p>);
print qq(<input type="submit" value="$text{'DISPLAY'}">);

print qq(</form>);

print qq(<p>);

if (grep (/$in{'logfile'}/, @logs))
{
  &clamav_print_log ($in{'logfile'}, $in{'lines'});
}

print qq(<hr>);
&footer("", $text{'RETURN_INDEX_MODULE'});

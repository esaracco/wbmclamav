#!/usr/bin/perl

# Copyright (C) 2003-2008
# Emmanuel Saracco <esaracco@users.labs.libre-entreprise.org>
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
&clamav_check_acl ('signature_use');
&ReadParse();

&header($text{'FORM_TITLE'}, "", undef, 1, 0);
print "<hr>\n";

print qq(<form method="POST" action="signatures_3step.cgi">);
print qq(<input type="hidden" name="signature" value="$in{'signature'}">);

print qq(<h1>$text{'SIGNATURES_TITLE'}</h1>);
print qq(<p>$text{'SIGNATURES_DESCRIPTION'}</p>);

print qq(<h2>$text{'SIGNATURES_THIRD_STEP'}</h2>);

print qq(<p>$text{'MSG_ERROR_NO_NAME'}</p>) if ($in{'error'});

print qq(<p>$text{'SIGNATURES_THIRD_STEP_DESCRIPTION'}</p>);

print qq(<table border=1>);
print qq(<tr><td $cb valign="top" nowrap>$text{'NAME'}:</td><td><input type="text" name="virus_name" value="$in{'virus_name'}" size="60"></td>);
printf "<tr><td $cb valign=\"top\" nowrap>$text{'SIGNATURE'}:</td><td>%s</td>", &clamav_html_cut ($in{'signature'}, 60);
print qq(</table>);

print qq(<p><input type="submit" name="next3" value="$text{'END'}"></p>);

print qq(</form>);

print qq(<hr>);
&footer("signatures_main.cgi", $text{'RETURN_SIGNATURES_MAIN'});

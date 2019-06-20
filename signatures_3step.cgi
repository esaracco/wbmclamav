#!/usr/bin/perl

# Copyright (C) 2003-2019
# Emmanuel Saracco <emmanuel@esaracco.fr>
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

my $whites = 0;

# if no name, the error
if (not $in{'virus_name'})
{
  $signature = &urlize ($in{'signature'});
  &redirect ("/$module_name/signatures_2step.cgi?error=1&signature=$signature");
}

&header($text{'FORM_TITLE'}, "", undef, 1, 0);
print "<hr>\n";

if ($in{'virus_name'} =~ / /)
{
  $in{'virus_name'} =~ s/ //g;
  $whites = 1;
}

print qq(<h1>$text{'SIGNATURES_TITLE'}</h1>);
print qq(<p>$text{'SIGNATURES_DESCRIPTION'}</p>);

print qq(<h2>$text{'SIGNATURES_BUILD_END_STEP'}</h2>);

print qq(<p>$text{'SIGNATURES_BUILD_END_STEP_DESCRIPTION'}</p>);

print qq(<p>$text{'MSG_WHITE_CHARS_REMOVED'}</p>) if ($whites);

printf "<pre style=\"background: silver;\">%s (Clam)=%s</pre>",
  $in{'virus_name'}, &clamav_html_cut ($in{'signature'}, 40);

print qq(<hr>);
&footer("signatures_main.cgi", $text{'RETURN_SIGNATURES_MAIN'});

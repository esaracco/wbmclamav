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

my $p1 = $in{'prefix0'}||'';
my $p2 = $in{'prefix1'}||'';
my $virus_name = '';
my $updated = 0;
$updated = 1 if ($in{'virus_name'} =~ s/\s//g);
$updated = 1 if ($in{'sha1'} =~ s/\s//g);

$virus_name .= "$p1." if ($p1);
$virus_name .= "$p2." if ($p2);
$virus_name .= $in{'virus_name'} if ($in{'virus_name'});



# check the validity of the given signature
if (my $ret = &clamav_check_signature ($in{'sha1'}.':'.$in{'size'}.':'.$virus_name))
{
  &redirect (sprintf (qq(/$module_name/signatures_1step.cgi?error=%s&sha1=%s&size=%s&virus_name=%s&prefix0=%s&prefix1=%s), &urlize($ret), &urlize($in{'sha1'}), &urlize($in{'size'}), &urlize($in{'virus_name'}), &urlize($p1), &urlize($p2)));
}

&header ($text{'FORM_TITLE'}, '', undef, 1, 0);
print "<hr>\n";

print qq(<h1>$text{'SIGNATURES_TITLE'}</h1>);
print qq(<p>$text{'SIGNATURES_DESCRIPTION'}</p>);

print qq(<h2>$text{'SIGNATURES_BUILD_END_STEP'}</h2>);

print qq(<p>$text{'MSG_WHITE_CHARS_REMOVED'}</p>) if ($updated);

printf qq(<pre style=\"background:silver;display:inline-block;padding:3px\">%s:%s:%s</pre>), &html_escape($in{'sha1'}), &html_escape($in{'size'}), &html_escape($virus_name);

print qq(<p>$text{'SIGNATURES_BUILD_END_STEP_DESCRIPTION'}</p>);

print qq(<hr>);
&footer ('signatures_main.cgi', $text{'RETURN_SIGNATURES_MAIN'});

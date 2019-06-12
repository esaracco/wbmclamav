#!/usr/bin/perl

# Copyright (C) 2003-2008
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
&ReadParse ();

&header($text{'FORM_TITLE'}, "", undef, 1, 0);
print "<hr>\n";

&clamav_signatures_check_config ();

print qq(<form method="POST" action="signatures_1step.cgi" enctype="multipart/form-data">);
print qq(<input type="hidden" name="main" value="1">);

print qq(<h1>$text{'SIGNATURES_TITLE'}</h1>);
print qq(<p>$text{'SIGNATURES_DESCRIPTION'}</p>);

print qq(<h2>$text{'SIGNATURES_FIRST_STEP'}</h2>);

print qq(<p>$text{'MSG_ERROR_FILE_UPLOAD'}</p>) if $in{'error'};

print qq(<input type="file" name="upload" size="30">);

print qq(<p><input type="submit" name="next" value="$text{'UPLOAD'}"></p>);

print qq(</form>);

print qq(<hr>);
&footer("", $text{'RETURN_INDEX_MODULE'});

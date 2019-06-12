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

require '../webmin/webmin-lib.pl';
require './clamav-lib.pl';
&clamav_check_acl ('signature_use');

if ($ENV{REQUEST_METHOD} eq "POST") { &ReadParseMime(); }
else { &ReadParse(); }

$upload = ($in{'upload'}) ? 1 : 0;

# if there is no file to upload, error
if ($in{'main'} and not $upload)
{
  &redirect ("/$module_name/signatures_main.cgi?error=1");
}

# check the validity of the given signature
$msg = '';
if ($in{'next2'})
{
  $signature = $in{'file_content'};
  $signature =~ s/[ \n\r\t]//g;
  
  $ret = &clamav_check_signature ($signature);
  if ($ret == 1)
  {
    $msg = $text{'MSG_ERROR_BAD_START'}; 
  }
  elsif ($ret == 2)
  {
    $msg = $text{'MSG_ERROR_BAD_SIZE'}; 
  }
  # if all is ok, go to the next step
  else
  {
    $signature = &urlize ($signature);
    &redirect ("/$module_name/signatures_2step.cgi?signature=$signature");
  }
}

&header($text{'FORM_TITLE'}, "", undef, 1, 0);
print "<hr>\n";

print qq(<form method="POST" action="$scriptname" enctype="multipart/form-data">);

print qq(<h1>$text{'SIGNATURES_TITLE'}</h1>);
print qq(<p>$text{'SIGNATURES_DESCRIPTION'}</p>);

print qq(<h2>$text{'SIGNATURES_SECOND_STEP'}</h2>);

print $msg if ($msg);

printf "<p>$text{'SIGNATURES_SECOND_STEP_DESCRIPTION'}</p>", 
  $text{'DISPLAY_STRINGS'}, $text{'DISPLAY_HEXA_ASCII'}, $text{'NEXT'};

print qq(<p><input type="submit" name="op" value="$text{'DISPLAY_STRINGS'}"> );
print qq(<input type="submit" name="op" value="$text{'DISPLAY_HEXA_ASCII'}"> );
print qq(<input type="submit" name="op" value="$text{'DISPLAY_HEXA'}"></p>);

if ($upload)
{
  $op = $text{'DISPLAY_STRINGS'};
  $tmp_file = &tempname(&file_basename($in{'upload_filename'}));
  open (H, ">$tmp_file");
  print H $in{'upload'};
  close (H);
}
else
{
  $op = $in{'op'};
  $tmp_file = $in{'tmp_file'};
}

if ($op eq $text{'DISPLAY_HEXA_ASCII'})
{
  open (H, "$all_path{'hexdump'}hexdump -C $tmp_file |");
}
elsif ($op eq $text{'DISPLAY_HEXA'})
{
  open (H, "$all_path{'hexdump'}hexdump $tmp_file |");
}
else
{
  open (H, "$all_path{'strings'}strings $tmp_file |");
}
@content = <H>;
close (H);

print qq(<input type="hidden" name="tmp_file" value="$tmp_file">);
print qq(<textarea cols="80" rows="30" name="file_content">@content</textarea>\n);

print qq(<p><input type="submit" name="next2" value="$text{'NEXT'}"></p>);

print qq(</form>);

print qq(<hr>);
&footer("signatures_main.cgi", $text{'RETURN_SIGNATURES_MAIN'});

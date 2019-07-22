#!/usr/bin/perl

# Copyright (C) 2003-2019
# Emmanuel Saracco <emmanuel@esaracco.fr>
#
# GNU GENERAL PUBLIC LICENSE

require '../webmin/webmin-lib.pl';
require './clamav-lib.pl';
&clamav_check_acl ('signature_use');

($ENV{REQUEST_METHOD} eq 'POST') ? &ReadParseMime() : &ReadParse();

my $sha1 = $in{'sha1'}||'';
my $size = $in{'size'}||0;
my $virus_name = $in{'virus_name'}||'';
my $error = $in{'error'}||'';
my $upload = ($in{'upload'}) ? 1 : 0;

# if there is no file to upload, error
if ($in{'main'} && !$upload)
{
  &redirect ("/$module_name/signatures_main.cgi?error=1");
}

&clamav_header ($text{'LINK_SIGNATURES'});

if ($upload)
{
  ($sha1, $size, $virus_name) = &clamav_build_signature (\%in);
}

print qq(<form method="POST" action="signatures_2step.cgi">);

printf qq(<input type="hidden" name="sha1" value="%s">), &html_escape($sha1);
printf qq(<input type="hidden" name="size" value="%s">), &html_escape($size);

print qq(<p>$text{'SIGNATURES_DESCRIPTION'}</p>);

print qq(<h2>$text{'SIGNATURES_THIRD_STEP'}</h2>);

print qq(<p><b>$error</b></p>) if ($error);

print qq(<p>$text{'SIGNATURES_THIRD_STEP_DESCRIPTION'}</p>);

print qq(<table border=1>);
print qq(<tr><td $cb valign="top" nowrap><b>$text{'NAME'}:</b></td><td>);
print &clamav_display_combos_viruses_prefixes ($in{'prefix0'}, $in{'prefix1'});
printf qq(<input type="text" name="virus_name" value="%s" size="60"></td>), &html_escape($virus_name);
printf qq(<tr><td $cb valign="top" nowrap><b>$text{'SIGNATURE'}:</b></td><td>%s</td>), &html_escape($sha1);
printf qq(<tr><td $cb valign="top" nowrap><b>$text{'FILE_SIZE'}:</b></td><td>%s</td>), &html_escape($size);
print qq(</table>);

print qq(<p/><button type="submit" name="next3" class="btn btn-success">$text{'END'}</button>);

print qq(</form>);

print qq(<hr>);
&footer("signatures_main.cgi", $text{'RETURN_SIGNATURES_MAIN'});

#!/usr/bin/perl

# Copyright (C) 2003-2019
# Emmanuel Saracco <emmanuel@esaracco.fr>
#
# GNU GENERAL PUBLIC LICENSE

require './clamav-lib.pl';
&clamav_check_acl ('logs_viewer_view');
&ReadParse ();

&clamav_header ($text{'LINK_LOGS'});

print qq(<form method="POST" action="$scriptname">);

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
print qq(<p/>);
print qq(<button type="submit" class="btn btn-success">$text{'DISPLAY'}</button>);

print qq(</form>);

print qq(<p/>);

if (grep (/$in{'logfile'}/, @logs))
{
  &clamav_print_log ($in{'logfile'}, $in{'lines'});
}

print qq(<hr>);
&footer("", $text{'RETURN_INDEX_MODULE'});

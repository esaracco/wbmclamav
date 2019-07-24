#!/usr/bin/perl

# Copyright (C) 2003-2019
# Emmanuel Saracco <emmanuel@esaracco.fr>
#
# GNU GENERAL PUBLIC LICENSE

require './clamav-lib.pl';
&clamav_check_acl ('logs_viewer_view');
&ReadParse ();

my ($_success, $_error) = ('', '');

&clamav_header ($text{'LINK_LOGS'});

print qq(<form method="POST" action="$scriptname">);

print qq(<p>$text{'LOGS_PAGE_DESCRIPTION'}</p>);

print qq($text{'DISPLAY'} );
print qq(<select name="lines">);
printf "<option value=\"0\"%s>%s</option>", 
  (!$in{'lines'}) ? ' selected="selected"' : '', $text{'ALL'};
foreach $value (qw(10 20 50 100 150 200 250 300))
{
  printf "<option value=\"%s\"%s>%s</option>", 
    $value, ($in{'lines'} eq $value) ? ' selected="selected"' : '', $value;
}
print qq(</select>);

print qq( $text{'LINES_OF'} );

@logs = &clamav_get_logfiles ();
print qq(<select name="logfile">);
foreach $log (@logs)
{
  printf ("<option value=\"%s\"%s>%s</option>",
    $log,
    ($log eq $in{'logfile'}) ? ' selected="selected"' : '',
    $log
  );
}
print qq(</select>);
print qq(<p/>);
print qq(<div><button type="submit" class="btn btn-success ui_form_end_submit"><i class="fa fa-fw fa-search"></i> <span>$text{'DISPLAY'}</span></button></div>);

print qq(</form>);

print qq(<p/>);

&clamav_print_log ($in{'logfile'}, $in{'lines'});

&clamav_footer ('', $text{'RETURN_INDEX_MODULE'}, $_success, $_error);

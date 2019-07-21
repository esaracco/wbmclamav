#!/usr/bin/perl

# Copyright (C) 2003-2019
# Emmanuel Saracco <emmanuel@esaracco.fr>
#
# GNU GENERAL PUBLIC LICENSE

require './clamav-lib.pl';
&clamav_check_acl ('directories_check_view');
&ReadParse ();

my $scandir = ($in{'next'} and $in{'what'} ne '');
my $msg = '';

&clamav_header ();

# delete files if requested
if (&clamav_get_acl ('directories_check_delete') == 1 && $in{'delete'} ne '')
{
  foreach my $key (keys %in)
  {
    next if ($key !~ /infected_file/);
    unlink ($in{$key}) if (-f $in{$key});
  }

  $msg = $text{'FILES_DELETED'};
}  

print qq(<h1>$text{'SCANDIR_TITLE'}</h1>);
print qq(<p>$text{'SCANDIR_DESCRIPTION'}</p>);

print qq(<p><b>$msg</b></p>) if ($msg ne '');

if ($in{'next'} && (! -d $in{'what'} || !&is_secure ($in{'what'})))
{
  print qq(<p><b>$text{'MSG_CLAMSCAN_BAD_SCAN_DIR'}</b></p>);
  $scandir = 0;
}

if ($in{'next'} && ($in{'move'} eq 'on') && (! -d $in{'move_path'} ||
                                             !&is_secure ($in{'move_path'})))
{
  print qq(<p><b>$text{'MSG_CLAMSCAN_BAD_MOVE_DIR'}</b></p>);
  $scandir = 0;
}

print qq(<form method="POST" action="$scriptname">);

printf qq(<input type="text" name="what" value="%s">), &html_escape ($in{'what'});
print &file_chooser_button('what', 1, 0);

if (&clamav_has_clamscan !~ /clamdscan/)
{
  $checked = ($in{'recursive'} eq 'on') ? ' CHECKED' : '';
  print qq(<p/><p><input id="recursive" type="checkbox" name="recursive" value="on"$checked /> );
  print qq(<label for="recursive">$text{'CHECK_SUB'}</label></p>);
}
else
{
  print qq(<input type="hidden" name="recursive" value=""/>);
}

$checked = ($in{'infected'} eq 'on') ? ' CHECKED' : '';
print qq(<p><input id="infected" type="checkbox" name="infected" value="on"$checked> );
print qq(<label for="infected">$text{'SHOW_INFECTED_ONLY'}</label></p>);

$checked = ($in{'move'} eq 'on') ? ' CHECKED' : '';
print qq(<p><input id="move" type="checkbox" name="move" value="on"$checked> );
printf qq(<label for="move">$text{'MOVE_INFECTED_FILES'}</label> <input type="text" name="move_path" value="%s">), &html_escape ($in{'move_path'});
print &file_chooser_button('move_path', 1, 0);
print qq(</p>);

print qq(<p><input type="submit" name="next" value="$text{'CHECK_DIR'}"></p>);

if ($scandir)
{
  print qq(<hr>);
 
  &clamav_scandir ($in{'what'}, 
    ($in{'recursive'} eq 'on'),
    ($in{'infected'} eq 'on'),
    (($in{'move'} eq 'on')) ? $in{'move_path'} : ''
  );
}

print qq(</form>);

print qq(<hr>);
&footer("", $text{'RETURN_INDEX_MODULE'});

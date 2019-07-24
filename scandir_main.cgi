#!/usr/bin/perl

# Copyright (C) 2003-2019
# Emmanuel Saracco <emmanuel@esaracco.fr>
#
# GNU GENERAL PUBLIC LICENSE

require './clamav-lib.pl';
&clamav_check_acl ('directories_check_view');
&ReadParse ();

my ($_success, $_error, $_info) = ('', '', '');
my $scandir = (defined($in{'next'}) && $in{'what'} ne '');

# delete files if requested
if (defined($in{'delete'}) && 
    &clamav_get_acl ('directories_check_delete') == 1)
{
  while (my ($k, $v) = each (%in))
  {
    if ($k =~ /infected_file/ &&
        $v =~ /virus|spam|badh|banned/ && &is_secure ($v))
    {
      unlink ($v);
    }
  }

  $_success = $text{'FILES_DELETED'};
}  

&clamav_header ($text{'LINK_SCANDIR'});

print qq(<form method="POST" action="$scriptname">);

print qq(<p>$text{'SCANDIR_DESCRIPTION'}</p>);

if (defined($in{'next'}) && (! -d $in{'what'} || !&is_secure ($in{'what'})))
{
  $_error = $text{'MSG_CLAMSCAN_BAD_SCAN_DIR'};
  $scandir = 0;
}

if (defined($in{'next'}) && $in{'move'} eq 'on' &&
    (! -d $in{'move_path'} || !&is_secure ($in{'move_path'})))
{
  $_error = $text{'MSG_CLAMSCAN_BAD_MOVE_DIR'};
  $scandir = 0;
}

printf qq(<input type="text" name="what" value="%s">), &html_escape ($in{'what'});
print &file_chooser_button('what', 1, 0);

if (&clamav_has_clamscan !~ /clamdscan/)
{
  $checked = ($in{'recursive'} eq 'on') ? ' checked="checked"' : '';
  print qq(<p/><p><input id="recursive" type="checkbox" name="recursive" value="on"$checked /> );
  print qq(<label for="recursive">$text{'CHECK_SUB'}</label></p>);
}
else
{
  print qq(<input type="hidden" name="recursive" value=""/>);
}

$checked = ($in{'infected'} eq 'on') ? ' checked="checked"' : '';
print qq(<p><input id="infected" type="checkbox" name="infected" value="on"$checked> );
print qq(<label for="infected">$text{'SHOW_INFECTED_ONLY'}</label></p>);

$checked = ($in{'move'} eq 'on') ? ' checked="checked"' : '';
print qq(<p><input id="move" type="checkbox" name="move" value="on"$checked> );
printf qq(<label for="move">$text{'MOVE_INFECTED_FILES'}</label> <span style="white-space:nowrap"><input type="text" name="move_path" value="%s">), &html_escape ($in{'move_path'});
print &file_chooser_button('move_path', 1, 0);
print qq(</span></p>);

print qq(<p/><div><button type="submit" name="next" class="btn btn-success ui_form_end_submit"><i class="fa fa-fw fa-search"></i> <span>$text{'CHECK_DIR'}</span></button></div>);

if ($scandir)
{
  print qq(<hr>);
 
  $_info = &clamav_scandir ($in{'what'}, 
    ($in{'recursive'} eq 'on'),
    ($in{'infected'} eq 'on'),
    (($in{'move'} eq 'on')) ? $in{'move_path'} : ''
  );
}

print qq(</form>);

&clamav_footer ('', $text{'RETURN_INDEX_MODULE'}, $_success, $_error, $_info);

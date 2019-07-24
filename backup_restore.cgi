#!/usr/bin/perl

# Copyright (C) 2003-2019
# Emmanuel Saracco <emmanuel@esaracco.fr>
#
# GNU GENERAL PUBLIC LICENSE

require './clamav-lib.pl';
&clamav_check_acl ('backup_restore_manage');
&ReadParse ();

my ($_success, $_error) = ('', '');
my $i = 0;
my @files = ();
my $restore_enabled = 0;

&clamav_header ($text{'LINK_BACKUP_RESTORE_PAGE'});

&clamav_main_check_config ();
&clamav_check_deps ();

if (defined($in{"init"}))
{
  &clamav_system_backup ();
  $_success = $text{"MSG_SUCCESS_BACKUP"};
}
elsif (defined($in{"restore"}))
{
  while (my ($k, $v) = each (%in))
  {
    push (@files, $v) if ($k =~ /^file/);
  }

  &clamav_system_restore (\@files, 0);
  $_success = $text{"MSG_SUCCESS_RESTORE"};
}

$restore_enabled = &clamav_system_ok ("restore");

print qq(<form method="POST" action="$scriptname">);

print qq(<p>$text{'BACKUP_RESTORE_DESCRIPTION'}</p>);

print qq(<table class="clamav" width="80%">);
print qq(<tr><td style="text-align:center;vertical-align:middle;width:50%">);
printf qq(<div><button type="submit" name="init" class="btn btn-success ui_form_end_submit"%s><i class="fa fa-fw fa-floppy-o"></i> <span>$text{"BACKUP"}</span></button></div></td>),
  ($restore_enabled) ? ' disabled' : '';
if (!&clamav_first_backup ())
{
  print qq(<td valign="top" align="right" width="50%">);
  print qq(<table class="clamav header">);
  ##print qq(<tr><td>$text{"FILE"}</td><td>$text{"RESTORE"}</td></tr>);
  print qq(<tr><td>$text{"FILES"}</td></tr>);
  foreach my $path (keys %{&clamav_get_system_files ()})
  {
    my $checked = 1;
    next if (! -f "$path");
    next if (! &clamav_backup_item_exists ($path));

    $checked = grep (/$path/, @files) if (@files);

    print qq(<tr><td><code>$path</code></td>);
    ##printf qq(<td><input type="checkbox" name="file%i" value="%s" %s%s></td></tr>), $i++, $path, " checked", " disabled";
    # FIXME Must we let the user choose the files to restore?
    #printf qq(<td><input type="checkbox" name="file%i" value="%s" %s%s></td></tr>), $i++, $path, ($checked) ? " checked" : "", ($restore_enabled) ? "" : " disabled";
  }
  print "</table>";
  printf
    qq(<p/><div><button type="submit" name="restore" class="btn btn-success ui_form_end_submit"%s><i class="fa fa-fw fa-restore fa-1_25x"></i> <span>$text{'RESTORE'}</span></button></div></td>),
      ($restore_enabled) ? '' : ' disabled';
}
print qq(</tr></table>);

print qq(</form>);

&clamav_footer ('', $text{'RETURN_INDEX_MODULE'}, $_success, $_error,
                  sprintf($text{'BACKUP_RESTORE_INFO'}, $module_name));

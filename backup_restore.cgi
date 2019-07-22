#!/usr/bin/perl

# Copyright (C) 2003-2019
# Emmanuel Saracco <emmanuel@esaracco.fr>
#
# GNU GENERAL PUBLIC LICENSE

require './clamav-lib.pl';
&clamav_check_acl ('backup_restore_manage');
&ReadParse ();

my $msg = "";
my $i = 0;
my @files = ();
my $restore_enabled = 0;

&clamav_header ($text{'LINK_BACKUP_RESTORE_PAGE'});

&clamav_main_check_config ();
&clamav_check_deps ();

if (defined($in{"init"}))
{
  &clamav_system_backup ();
  $msg = qq(<b>$text{"MSG_SUCCESS_BACKUP"}</b>);
}
elsif (defined($in{"restore"}))
{
  while (my ($k, $v) = each (%in))
  {
    push (@files, $v) if ($k =~ /^file/);
  }

  &clamav_system_restore (\@files, 0);
  $msg = qq(<b>$text{"MSG_SUCCESS_RESTORE"}</b>);
}

$restore_enabled = &clamav_system_ok ("restore");

print qq(<form method="POST" action="$scriptname">);

print qq(<b>$msg</b>) if ($msg);

printf qq(<p>$text{'BACKUP_RESTORE_DESCRIPTION'}</p>), $module_name;

print qq(<table width="80%" border=1>);
print qq(<tr><td valign="center" align="center" width="50%">);
printf qq(<button type="submit" name="init" class="btn btn-success"%s>$text{"BACKUP"}</button></td>),
  ($restore_enabled) ? ' disabled' : '';
if (!&clamav_first_backup ())
{
  print qq(<td valign="top" align="right" width="50%">);
  print "<table border=1>";
  print qq(<tr $tb><td><b>$text{"FILE"}</b></td><td><b>$text{"RESTORE"}</b></td></tr>);
  foreach my $path (keys %{&clamav_get_system_files ()})
  {
    my $checked = 1;
    next if (! -f "$path");
    next if (! &clamav_backup_item_exists ($path));

    $checked = grep (/$path/, @files) if (@files);

    print qq(<tr><td><code>$path</code></td>);
    printf qq(<td><input type="checkbox" name="file%i" value="%s" %s%s></td></tr>), $i++, $path, " checked", " disabled";
    # FIXME Must we let the user choose the files to restore?
    #printf qq(<td><input type="checkbox" name="file%i" value="%s" %s%s></td></tr>), $i++, $path, ($checked) ? " checked" : "", ($restore_enabled) ? "" : " disabled";
  }
  print "</table>";
  printf
    qq(<p/><button type="submit" name="restore" class="btn btn-success"%s>$text{'RESTORE'}</button></td>),
      ($restore_enabled) ? '' : ' disabled';
}
print qq(</tr></table>);

print qq(</form>);

print qq(<p>);

print qq(<hr>);
&footer("", $text{'RETURN_INDEX_MODULE'});

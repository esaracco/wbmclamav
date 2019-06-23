#!/usr/bin/perl

# Copyright (C) 2003-2015
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
&clamav_check_acl ('backup_restore_manage');
&ReadParse ();

my $msg = "";
my $i = 0;
my @files = ();
my $restore_enabled = 0;

&header($text{'FORM_TITLE'}, "", undef, 1, 0);
print "<hr>\n";

&clamav_main_check_config ();
&clamav_check_perl_deps ();

if ($in{"init"})
{
  &clamav_system_backup ();
  $msg = qq(<b>$text{"MSG_SUCCESS_BACKUP"}</b>);
}
elsif ($in{"restore"})
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

print qq(<h1>$text{"BACKUP_RESTORE_TITLE"}</h1>\n);

print qq(<b>$msg</b>) if ($msg);

printf qq(<p>$text{'BACKUP_RESTORE_DESCRIPTION'}</p>), $module_name;

print qq(<table width="80%" border=1>);
print qq(<tr><td valign="center" align="center" width="50%">);
printf qq(<input type="submit" name="init" value="$text{"BACKUP"}"%s></td>),
  ($restore_enabled) ? " disabled" : "";
if (!&clamav_first_backup ())
{
  print qq(<td valign="top" align="right" width="50%">);
  print "<table border=1>";
  print qq(<tr $tb><th>$text{"FILE"}</th><th>$text{"RESTORE"}</th></tr>);
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
    qq(<input type="submit" name="restore" value="$text{'RESTORE'}"%s></td>),
      ($restore_enabled) ? "" : " disabled";
}
print qq(</tr></table>);

print qq(</form>);

print qq(<p>);

print qq(<hr>);
&footer("", $text{'RETURN_INDEX_MODULE'});

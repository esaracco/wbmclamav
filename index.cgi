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
&ReadParse ();

# If the system has not yet been prepared for this module.
if (&clamav_system_ok ("backup"))
{
  &redirect ("/$module_name/backup_restore.cgi");
}

@links = ();
@titles = ();
@icons = ();

sub clamav_add_if_acl_ok ($ $ $ $)
{
  my ($acl, $link, $title, $icon) = @_;

  if (&clamav_get_acl ($acl) == 1)
  {
    push @links, $link;
    push @titles, $title;
    push @icons, $icon;
  }
}

&clamav_add_if_acl_ok ('backup_restore_manage', 'backup_restore.cgi', 
  $text{'LINK_BACKUP_RESTORE_PAGE'}, 'images/backup_restore.png');
&clamav_add_if_acl_ok ('quarantine_view', 'quarantine_main.cgi', 
  $text{'LINK_QUANRANTINE_PAGE'}, 'images/quarantine.png');
&clamav_add_if_acl_ok ('database_update_view', 'updates_main.cgi',
  $text{'LINK_UPDATE_PAGE'}, 'images/updates.png');
&clamav_add_if_acl_ok ('directories_check_view', 'scandir_main.cgi',
  $text{'LINK_SCANDIR'}, 'images/scandir.png');
&clamav_add_if_acl_ok ('global_settings_view', 'settings_main.cgi',
  $text{'LINK_SETTINGS'}, 'images/settings.png');
&clamav_add_if_acl_ok ('clamav_remote_control', 'remote_control_main.cgi',
  $text{'LINK_REMOTE_CONTROL'}, 'images/remote_control.png');
&clamav_add_if_acl_ok ('logs_viewer_view', 'logs_main.cgi',
  $text{'LINK_LOGS'}, 'images/logs.png');
&clamav_add_if_acl_ok ('database_search_search', 'vdb_search_main.cgi',
  $text{'LINK_VDB_SEARCH'}, 'images/vdb_search.png');
&clamav_add_if_acl_ok ('signature_use', 'signatures_main.cgi',
  $text{'LINK_SIGNATURES'}, 'images/signatures.png');

&header($text{'FORM_TITLE'}, undef, undef, 1, 1, 0, undef, undef, undef, "<a href=\"http://wbmclamav.esaracco.fr\" target=\"_BLANK\">$text{'HOMEPAGE'}</a>&nbsp;|&nbsp;<a href=\"http://wbmclamav.esaracco.fr/download\" target=\"_BLANK\">$text{'DOWNLOAD'}</a>&nbsp;|&nbsp<a href=\"http://www.clamav.net/download\" target=\"_BLANK\">$text{'LATEST_CLAMAV'}</a>");
print "<hr>\n";

&clamav_main_check_config ();
&clamav_check_perl_deps ();

print qq(<p>$text{'INDEX_PAGE_DESCRIPTION'}</p>\n);

if (&clamav_get_acl ('clamav_start_stop') == 1)
{
  if (&clamav_is_clamd_installed ())
  {
    # activate
    if ($in{'status'} eq '1')
    {
      &clamav_activate_clamd ();
    }
    # deactivate
    elsif ($in{'status'} eq '0')
    {
      &clamav_deactivate_clamd ();
    }
  
    print qq(<form method="POST" action="$scriptname">\n);
    print qq(<p align="center">\n);

    if (&clamav_is_clamd_alive () == ())
    {
      print qq(<input type="hidden" name="status" value="1">);
      print qq(<input type="submit" value="$text{'ACTIVATE'}">\n);
    }
    else
    {
      print qq(<input type="hidden" name="status" value="0">);
      print qq(<input type="submit" value="$text{'DEACTIVATE'}">\n);
    }
    print qq(</p></form>\n);
  }
}

print qq(<p>);
&icons_table (\@links, \@titles, \@icons);
print qq(</p>);

print qq(<hr>);
&clamav_footer ();
&footer("/", $text{'index'});



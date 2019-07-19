#!/usr/bin/perl

# Copyright (C) 2003-2008
# Emmanuel Saracco <emmanuel@esaracco.fr>
#
# GNU GENERAL PUBLIC LICENSE

require 'clamav-lib.pl';

sub acl_security_form ( $ )
{
  $o = $_[0];
  
  print qq(<tr><td colspan="4" $tb><b>$text{"BACKUP_RESTORE"}</b></td></tr>);
  &clamav_print_line ($text{'CONTROL'}, "backup_restore_manage", $o);

  print qq(<tr><td colspan="4" $tb><b>ClamAV</b></td></tr>);
  &clamav_print_line ($text{'START_STOP'}, "clamav_start_stop",$o);
  &clamav_print_line ($text{'REMOTE_CONTROL'}, "clamav_remote_control",$o);
  
  print qq(<tr><td colspan="4" $tb><b>$text{'QUARANTINE'}</b></td></tr>);
  &clamav_print_line ($text{'VIEW'}, "quarantine_view",$o);
  &clamav_print_line ($text{'DELETE'}, "quarantine_delete",$o);
  &clamav_print_line ($text{'RESEND'}, "quarantine_resend",$o);
  &clamav_print_line ($text{'EXPORT'}, "quarantine_export",$o);
  
  print qq(<tr><td colspan="4" $tb><b>$text{'DATABASE_UPDATE'}</b></td></tr>);
  &clamav_print_line ($text{'VIEW'}, "database_update_view",$o);
  &clamav_print_line ($text{'UPDATE'}, "database_update_update",$o);
  
  print qq(<tr><td colspan="4" $tb><b>$text{'DIRECTORIES_CHECK'}</b></td></tr>);
  &clamav_print_line ($text{'CHECK'}, "directories_check_view",$o);
  &clamav_print_line ($text{'DELETE'}, "directories_check_delete",$o);

  print qq(<tr><td colspan="4" $tb><b>$text{'GLOBAL_SETTINGS'}</b></td></tr>);
  &clamav_print_line ($text{'VIEW'}, "global_settings_view",$o);
  &clamav_print_line ($text{'WRITE_DELETE'}, "global_settings_write",$o);
  
  print qq(<tr><td colspan="4" $tb><b>$text{'LOGS_VIEWER'}</b></td></tr>);
  &clamav_print_line ($text{'VIEW'}, "logs_viewer_view",$o);
  
  print qq(<tr><td colspan="4" $tb><b>$text{'VIRUSES_SEARCH'}</b></td></tr>);
  &clamav_print_line ($text{'SEARCH'}, "database_search_search",$o);

  print qq(<tr><td colspan="4" $tb><b>$text{'SIGNATURES_EXTRACTION'}</b></td></tr>);
  &clamav_print_line ($text{'USE'}, "signature_use",$o);
}

sub acl_security_save
{
  foreach ((
    'clamav_remote_control', 'clamav_start_stop', 'quarantine_view', 
    'quarantine_delete',  'quarantine_resend', 'quarantine_purge', 
    'quarantine_export', 'database_update_view', 'database_update_update', 
    'directories_check_view', 'directories_check_delete', 
    'global_settings_view', 'global_settings_write', 'logs_viewer_view', 
    'database_search_search', 'signature_use', 'backup_restore_manage'
  )) {$_[0]->{$_} = $in{$_}}
}

sub clamav_print_line ( $ $ $ )
{
  my ($title, $var, $o) = @_;
  
  printf ("
    <tr>
    <td><b>$title</b></td>
    <td nowrap><input type=radio name=$var value=1%s>&nbsp;Yes&nbsp;<input type=radio name=$var value=0%s>&nbsp;No</td>
    <td colspan=2>&nbsp;</td>
    </tr>
  ",
  $o->{$var} == 1 ? ' checked' : '',
  $o->{$var} == 0 ? ' checked' : '');
}

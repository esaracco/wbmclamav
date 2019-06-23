#!/usr/bin/perl

# Copyright (C) 2003-2008
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
&clamav_check_acl ('database_update_view');
&ReadParse ();

&header($text{'FORM_TITLE'}, "", undef, 1, 0);
print "<hr>\n";

print qq(<form method="POST" action="$scriptname">);
print qq(<p>$text{'UPDATE_PAGE_DESCRIPTION_GENERAL'}</p>);

($main, $daily, $main_infos, $daily_infos) = &clamav_get_last_db_update ();
if ($main ne '')
{
  print qq(<p>$text{'LAST_UPDATES_DESCRIPTION'}</p>);
  print qq(<table border="0">);
  print qq(<tr><td $cb>$text{'MAIN_UPDATE_DATE'}</td>
               <td>$main \($main_infos\)</td></tr>);
  if ($daily)
  {
    print qq(<tr><td $cb>$text{'DAILY_UPDATE_DATE'}</td>
                 <td>$daily \($daily_infos\)</td></tr>);
  }
  print qq(</table>);
}
else
{
  print qq(<p><b>ATTENTION</b>: $text{'NOT_YET_UPDATED'}</p>);
}

($proxy_server, $proxy_port) = &clamav_get_proxy_settings ();
if ($proxy_server)
{
  print qq(<p>$text{'USE_PROXY_SETTINGS'}</p>);
  print qq(<table border="0">);
  print qq(<tr><td $cb><b>$text{'HOST'}</b></td>);
  print qq(<td>$proxy_server</td></tr>);
  print qq(<tr><td $cb><b>$text{'PORT'}</b></td>);
  print qq(<td>$proxy_port</td></tr>);
  print qq(</table>);
}

if (&clamav_get_acl ('database_update_update') == 1)
{
  print qq(<p><h1>$text{'UPDATE_TITLE_MANUAL'}</h1></p>);

  if ($in{'update'})
  {
    print qq(<p>$text{'UPDATE_REPORT'}</p>);
    &clamav_update_db ();
  }
  print qq(<p>$text{'UPDATE_PAGE_DESCRIPTION_MANUAL'}</p>);
  print qq(<p><input type="submit" name="update" value="$text{'UPDATE_NOW'}">);
  print qq(</p>);
}

$res = &clamav_verif_refresh_method_ok ();

if (&clamav_value_is ($res, "ER_CRON_PACKAGE"))
{
  print qq(<p><b>$text{'WARNING'}</b>: $text{'BAD_CONFIG_6'}</p>);
}
elsif (!&clamav_update_manual ())
{
  print qq(<p><h1>$text{'UPDATE_TITLE_AUTO'}</h1></p>);
  
  # Config say to use a daemon but no daemon exist on the system
  if (&clamav_value_is ($res, "ER_DAEMON_NOEXIST"))
  {
    print qq(<p><b>$text{'WARNING'}</b>: $text{'BAD_CONFIG_1'}</p>);
  }
  # Config say to use a daemon, but a cron exist on the system
  elsif (&clamav_value_is ($res, "ER_DAEMON_CRONEXIST"))
  {
    print qq(<p><b>$text{'WARNING'}</b>: $text{'BAD_CONFIG_2'}</p>);
  }
  # Config say tu use cron, but a daemon exist on the system
  elsif (&clamav_value_is ($res, "ER_CRON_DAEMONEXIST"))
  {
    print qq(<p><b>$text{'WARNING'}</b>: $text{'BAD_CONFIG_3'}</p>);
  }
  # Config and system are ok
  else
  {
    print qq(<p>$text{'UPDATE_PAGE_DESCRIPTION_AUTO'}</p>);
  
    # user choose to update db with cron
    if ($config{'clamav_refresh_use_cron'})
    {
      if ($in{'next'} && &clamav_get_acl ('database_update_update') == 1)
      {
        if ($in{'noupdate'})
        {
          &clamav_set_db_no_autoupdate ();
        }
        elsif (defined $in{'hour'})
        {
          my $hour = $in{'hour'};
  
  	$hour = "*/$hour" if ($in{'every_hours'} and $in{'hour'});
          &clamav_set_cron_update ($hour, $in{'day'});
        }
        print qq(<p><b>$text{'MSG_SUCCESS_FREQUENCY_UPDATE'}</b></p>);
      }
      @cron_line = &clamav_get_cron_settings ('update');
      print &clamav_cron_settings_table ($cron_line[1], $cron_line[4]);
      $checked = ($#cron_line <= 0) ? ' CHECKED' : '';
    }
    # user choose to update db with daemon
    else
    {
      print qq(<p>$text{'UPDATE_FRESHCLAM_DAEMON_CHOICE'}</p>);
      
      if ($in{'next'} && &clamav_get_acl ('database_update_update') == 1)
      {
        my $ret = 0;
	
        if ($in{'noupdate'})
        {
          $ret = &clamav_set_db_no_autoupdate ();
        }
        elsif ($in{'freq'})
        {
          $ret = &clamav_set_freshclam_daemon_settings ($in{'oldfreq'}, 
                                                        $in{'freq'});
        }
  
        if ($ret)
	{
	  print qq(<p><b>$text{'MSG_SUCCESS_FREQUENCY_UPDATE'}</b></p>);
	}
	else
	{
	  print qq(<p><b>$text{'MSG_ERROR_FREQUENCY_UPDATE'}</b></p>);
	}
      }
      
      $daemon_setting = &clamav_get_freshclam_daemon_settings ();
      $on = &clamav_get_freshclam_daemon_state ();
      print qq(<input type="hidden" name="oldfreq" value="$daemon_setting">);
      print &clamav_freshclam_daemon_settings_table ($daemon_setting); 
      $checked = ($on) ? '' : ' CHECKED';
    }
  
    print qq(<p>);
    print qq(<input id="noupdate" type="checkbox" name="noupdate" 
                    value="on"$checked>);
    print qq( <label for="noupdate">$text{'NEVER_REFRESH'}</label>);
    print qq(</p>);
  
    if (&clamav_get_acl ('database_update_update') == 1)
    {
      print qq(<p>);
      print qq(<input type="submit" name="next" value="$text{'APPLY'}">);
      print qq(</p>);
    }
  }
}
else
{
  # Config say manual update, but a cron exist on the system
  if (&clamav_value_is ($res, "ER_MANUAL_CRONEXIST"))
  {
    print qq(<p><b>$text{'WARNING'}</b>: $text{'BAD_CONFIG_4'}</p>);
  }
  # Config say manual update, but a daemon exist on the system
  elsif (&clamav_value_is ($res, "ER_MANUAL_DAEMONEXIST"))
  {
    print qq(<p><b>$text{'WARNING'}</b>: $text{'BAD_CONFIG_5'}</p>);
  }
}

print qq(</form>);

print qq(<hr>);
&footer("", $text{'RETURN_INDEX_MODULE'});

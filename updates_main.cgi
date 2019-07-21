#!/usr/bin/perl

# Copyright (C) 2003-2019
# Emmanuel Saracco <emmanuel@esaracco.fr>
#
# GNU GENERAL PUBLIC LICENSE

use lib './lib';
use ClamavConstants;

require './clamav-lib.pl';
&clamav_check_acl ('database_update_view');
&ReadParse ();

&clamav_header ();

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

if ($res == ER_CRON_PACKAGE)
{
  print qq(<p><b>$text{'WARNING'}</b>: $text{'BAD_CONFIG_6'}</p>);
}
elsif (!&clamav_update_manual ())
{
  print qq(<p><h1>$text{'UPDATE_TITLE_AUTO'}</h1></p>);
  
  # Config say to use a daemon but no daemon exist on the system
  if ($res == ER_DAEMON_NOEXIST)
  {
    print qq(<p><b>$text{'WARNING'}</b>: $text{'BAD_CONFIG_1'}</p>);
  }
  # Config say to use a daemon, but a cron exist on the system
  elsif ($res == ER_DAEMON_CRONEXIST)
  {
    print qq(<p><b>$text{'WARNING'}</b>: $text{'BAD_CONFIG_2'}</p>);
  }
  # Config say tu use cron, but a daemon exist on the system
  elsif ($res == ER_CRON_DAEMONEXIST)
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
      $checked = (@cron_line) ? '' : ' checked="checked"';
      print &clamav_cron_settings_table ($cron_line[1]||0, $cron_line[4]||7,
                                         $checked);
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
      $on = &clamav_is_freshclam_alive ();
      $checked = ($on) ? '' : ' checked="checked"';
      print qq(<input type="hidden" name="oldfreq" value="$daemon_setting">);
      print &clamav_freshclam_daemon_settings_table ($daemon_setting, $checked); 
    }
  
    print qq(<p>);
    print qq(<input id="noupdate" type="checkbox" name="noupdate" onchange="document.getElementById('cron-frequency').className=(this.checked)?'disabled':''"
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
  if ($res == ER_MANUAL_CRONEXIST)
  {
    print qq(<p><b>$text{'WARNING'}</b>: $text{'BAD_CONFIG_4'}</p>);
  }
  # Config say manual update, but a daemon exist on the system
  elsif ($res == ER_MANUAL_DAEMONEXIST)
  {
    print qq(<p><b>$text{'WARNING'}</b>: $text{'BAD_CONFIG_5'}</p>);
  }
}

print qq(</form>);

print qq(<hr>);
&footer ('', $text{'RETURN_INDEX_MODULE'});

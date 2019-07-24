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

my ($_success, $_error, $_info) = ('', '', '');
my $update = defined($in{'update'});
my $main = $in{'main'};
my $daily = $in{'daily'};
my $main_infos = $in{'main_infos'};
my $daily_infos = $in{'daily_infos'};
my $update_report = &clamav_update_db () if ($update);

&clamav_header ($text{'LINK_UPDATE_PAGE'});

print qq(<form method="POST" action="$scriptname">);
print qq(<p>$text{'UPDATE_PAGE_DESCRIPTION_GENERAL'}</p>);

if (!$main || $update)
{
  ($main, $daily, $main_infos, $daily_infos) = &clamav_get_last_db_update ();
}

print qq(<input type="hidden" name="main" value="$main"/>);
print qq(<input type="hidden" name="daily" value="$daily"/>);
print qq(<input type="hidden" name="main_infos" value="$main_infos"/>);
print qq(<input type="hidden" name="daily_infos" value="$daily_infos"/>);

if ($main ne '')
{
  print qq(<p>$text{'LAST_UPDATES_DESCRIPTION'}</p>);
  print qq(<table class="clamav keys-values">);
  print qq(<tr><td>$text{'MAIN_UPDATE_DATE'}: </td>
               <td>&nbsp;$main \($main_infos\)</td></tr>);
  if ($daily)
  {
    print qq(<tr><td>$text{'DAILY_UPDATE_DATE'}: </td>
                 <td>&nbsp;$daily \($daily_infos\)</td></tr>);
  }
  print qq(</table>);
}
else
{
  $_info = $text{'NOT_YET_UPDATED'};
}

($proxy_server, $proxy_port) = &clamav_get_proxy_settings ();
if ($proxy_server)
{
  print qq(<p/>$text{'USE_PROXY_SETTINGS'}<p/>);
  print qq(<table class="clamav keys-values">);
  print qq(<tr><td>$text{'HOST'}: </td>);
  print qq(<td>$proxy_server</td></tr>);
  print qq(<tr><td>$text{'PORT'}: </td>);
  print qq(<td>$proxy_port</td></tr>);
  print qq(</table>);
}

if (&clamav_get_acl ('database_update_update') == 1)
{
  print qq(<p/><h2>$text{'UPDATE_TITLE_MANUAL'}</h2>);

  if (defined($in{'update'}))
  {
    print qq(<p>$text{'UPDATE_REPORT'}</p>);

    print $update_report;

    $_success = $text{'MSG_SUCCESS_DATABASE_UPDATED'};
  }
  else
  {
    print qq(<p>$text{'UPDATE_PAGE_DESCRIPTION_MANUAL'}</p>);
  }
  print qq(<p/><div><button type="submit" name="update" class="btn btn-success ui_form_end_submit"><i class="fa fa-fw fa-refresh"></i> <span>$text{'UPDATE_NOW'}</span></button></div>);
}

$res = &clamav_verif_refresh_method_ok ();

if ($res == ER_CRON_PACKAGE)
{
  $_error = $text{'BAD_CONFIG_6'};
}
elsif (!&clamav_update_manual ())
{
  # Config say to use a daemon but no daemon exist on the system
  if ($res == ER_DAEMON_NOEXIST)
  {
    $_error = $text{'BAD_CONFIG_1'};
  }
  # Config say to use a daemon, but a cron exist on the system
  elsif ($res == ER_DAEMON_CRONEXIST)
  {
    $_error = $text{'BAD_CONFIG_2'};
  }
  # Config say tu use cron, but a daemon exist on the system
  elsif ($res == ER_CRON_DAEMONEXIST)
  {
    $_error = $text{'BAD_CONFIG_3'};
  }
  # Config and system are ok
  else
  {
    print qq(<p/><h2>$text{'UPDATE_TITLE_AUTO'}</h2>);

    print qq(<p>$text{'UPDATE_PAGE_DESCRIPTION_AUTO'}</p>);
  
    # user choose to update db with cron
    if ($config{'clamav_refresh_use_cron'})
    {
      if (defined($in{'next'}) &&
          &clamav_get_acl ('database_update_update') == 1)
      {
        if (defined($in{'noupdate'}))
        {
          &clamav_set_db_no_autoupdate ();
        }
        elsif (defined $in{'hour'})
        {
          my $hour = $in{'hour'};
  
          $hour = "*/$hour" if (defined($in{'every_hours'}) && $hour);
          &clamav_set_cron_update ($hour, $in{'day'});
        }
        $_success = $text{'MSG_SUCCESS_FREQUENCY_UPDATE'};
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
      
      if (defined($in{'next'}) &&
          &clamav_get_acl ('database_update_update') == 1)
      {
        my $ret = 0;
	
        if (defined($in{'noupdate'}))
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
	  $_success = $text{'MSG_SUCCESS_FREQUENCY_UPDATE'};
	}
	else
	{
	  $_error = $text{'MSG_ERROR_FREQUENCY_UPDATE'};
	}
      }
      
      $daemon_setting = &clamav_get_freshclam_daemon_settings ();
      $on = &clamav_is_freshclam_alive ();
      $checked = ($on) ? '' : ' checked="checked"';
      print qq(<input type="hidden" name="oldfreq" value="$daemon_setting">);
      print &clamav_freshclam_daemon_settings_table ($daemon_setting, $checked); 
    }
  
    print qq(<p/>);
    print qq(<input id="noupdate" type="checkbox" name="noupdate" onchange="HTMLClassReplace(document.getElementById('apply'), 'btn-success', 'btn-warning');if(this.checked){HTMLClassAdd(document.getElementById('cron-frequency'), 'disabled')}else{HTMLClassRemove(document.getElementById('cron-frequency'), 'disabled')}" value="on"$checked>);
    print qq( <label for="noupdate">$text{'NEVER_REFRESH'}</label>);
  
    if (&clamav_get_acl ('database_update_update') == 1)
    {
      print qq(<p/>);
      print qq(<div><button type="submit" name="next" id="apply" class="btn btn-success ui_form_end_submit"><i class="fa fa-fw fa-check-circle-o"></i> <span>$text{'APPLY'}</span></button></div>);
    }
  }
}
else
{
  # Config say manual update, but a cron exist on the system
  if ($res == ER_MANUAL_CRONEXIST)
  {
    $_error = $text{'BAD_CONFIG_4'};
  }
  # Config say manual update, but a daemon exist on the system
  elsif ($res == ER_MANUAL_DAEMONEXIST)
  {
    $_error = $text{'BAD_CONFIG_5'};
  }
}

print qq(</form>);

&clamav_footer ('', $text{'RETURN_INDEX_MODULE'}, $_success, $_error, $_info);

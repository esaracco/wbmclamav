# Copyright (C) 2003-2019
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

use WebminCore;
&init_config ();

use constant {
  # Min stable clamav version supported by this module
  SUPPORTED_VERSION => '0.101.2',
  # Min devel (Git) clamav version supported by this module
  SUPPORTED_DEVEL_DATE => '20190326',
  # Max items to display/page for quarantine search result
  MAX_PAGE_ITEMS => 50,
  # Default SpamAssassin user (can be overrided by module configuration)
  DEFAULT_CLAMAV_SPAM_USER => 'amavis',
  # Default clamav system user (can be overrided by module configuration)
  DEFAULT_CLAMAV_SYS_USER => 'clamav',
  # Default clamav system user (can be overrided by module configuration)
  DEFAULT_CLAMAV_SYS_GROUP => 'clamav',

  # System crontab file
  CRONTAB_PATH => '/etc/crontab',
  # Module specific crontab file (in case CRONTAB_PATH was not available)
  CRONTAB_MODULE_PATH => '/etc/cron.d/webmin_clamav',

  # Content scanner constants
  CS_NONE => 0,
  CS_AMAVIS => 1,
  CS_AMAVIS_NG => 2,
  CS_CLAMAV_MILTER => 3,
  CS_MAILSCANNER => 4,
  CS_QMAILSCANNER => 5,

  # Quarantine graph constants
  QG_WIDTH => 900,
  QG_HEIGHT => 500,

  # Update method constants
  UP_DAEMON => 0,
  UP_CRON => 1,
  UP_MANUAL => 2,

  KO => 0,
  OK => 1,

  # Cron/daemon errors for clamav refresh method
  ER_DAEMON_NOEXIST => 2,
  ER_DAEMON_CRONEXIST => 3,
  ER_CRON_DAEMONEXIST => 4,
  ER_MANUAL_CRONEXIST => 5,
  ER_MANUAL_DAEMONEXIST => 6,
  ER_CRON_PACKAGE => 7,

  NET_PING_KO => 8
};

our $clamav_error = '';

# Retreive ACLs for this module
my %ACLs = &get_module_acl ();

# Global array for bad perl modules dependencies
my %deps = ();

eval'use POSIX';$deps{'POSIX'} if ($@);
eval'use File::Basename';$deps{'File::Basename'} = 1 if ($@);
eval'use File::Path qw(make_path)';$deps{'File::Path'} = 1 if ($@);
eval'use File::Find';$deps{'File::Find'} = 1 if ($@);
eval'use File::Copy';$deps{'File::Copy'} = 1 if ($@);
eval'use Date::Manip';$deps{'Date::Manip'} if ($@);
eval'use Compress::Zlib';$deps{'Compress::Zlib'} = 1 if ($@);
eval'use HTML::Entities';$deps{'HTML::Entities'} = 1 if ($@);
eval'use Getopt::Long';$deps{'use Getopt::Long'} = 1 if ($@);
eval'use IO::File';$deps{'use IO::File'} = 1 if ($@);
eval'use Net::SMTP';$deps{'use Net::SMTP'} = 1 if ($@);
eval'use IO::Socket';$deps{'use IO::Socket'} = 1 if ($@);
eval'use Mail::Internet';$deps{'Mail::Internet'} = 1 if ($@);
eval'use Mail::SpamAssassin';$deps{'Mail::SpamAssassin'} = 1 if ($@);
eval'use GD';$deps{'GD'} = 1 if ($@);
eval'use GD::Graph::lines';$deps{'GD::Graph::lines'} = 1 if ($@);
eval'use Mail::Mbox::MessageParser';$deps{'Mail::Mbox::MessageParser'}=1 if($@);

# Freshclam configuration
my %freshclam_config = ();

# Clamav configuration
my %clamav_config = ();

# Clean config inputs
&clamav_trim_config ();

# If the system has not yet been prepared for this module.
if (&clamav_system_ok ('backup') &&
    $scriptname ne 'backup_restore.cgi' &&
    # Do nothing if webmin is uninstalling us
    $scriptname ne 'delete_mod.cgi')
{
  &redirect ("/$module_name/backup_restore.cgi");
}

# clamav_get_acl ( $ )
# IN: ACL
# OUT: The ACL value
#
# Return the value of the given ACL
#
sub clamav_get_acl ( $ )
{
  my $acl = shift;

  return $ACLs{$acl};
}

# clamav_check_acl ($ )
# IN: ACL
# OUT: -
#
# Check if the current user can perform the requested action. If not, 
# execution is cancelled and a error message is displayed
#
sub clamav_check_acl ( $ )
{
  my $acl = shift;

  if (($ACLs{$acl} != 1))
  {
    &header($text{'FORM_TITLE'}, '', undef, 1, 0);
    print qq(<hr>);
    &clamav_check_config_exit ($text{'MSG_ACL_DENIED'})
  }
}

# clamav_is_qmailscanner ()
# IN: -
# OUT: TRUE if qmailscanner is installed
#
# Check if qmailscanner is installed
# 
sub clamav_is_qmailscanner ()
{
  return ($config{'clamav_quarantine_soft'} == CS_QMAILSCANNER);
}

# clamav_is_mailscanner ()
# IN: -
# OUT: TRUE if mailscanner is installed
#
# Check if mailscanner is installed
# 
sub clamav_is_mailscanner ()
{
  return ($config{'clamav_quarantine_soft'} == CS_MAILSCANNER &&
          &has_command ('MailScanner'));
}

# clamav_is_milter ()
# IN: -
# OUT: TRUE if clamav-milter is installed
#
# Check if clamav-milter is installed
# 
sub clamav_is_milter ()
{
  return ($config{'clamav_quarantine_soft'} == CS_CLAMAV_MILTER && 
          &has_command ('clamav-milter'));
}

# clamav_is_amavis_ng ()
# IN: -
# OUT: TRUE if amavis-ng is installed
#
# Check if amavis-ng is installed
# 
sub clamav_is_amavis_ng ()
{
  return ($config{'clamav_quarantine_soft'} == CS_AMAVIS_NG &&
    (
      &has_command ('amavis-ng') ||
      &has_command ('amavis')
    )
  );
}

# clamav_is_amavisd_new ()
# IN: -
# OUT: TRUE if amavisd-new is installed
#
# Check if amavisd-new is installed
#
sub clamav_is_amavisd_new ()
{
  return ($config{'clamav_quarantine_soft'} == CS_AMAVIS && 
    (
      &has_command ('amavisd-new') || 
      &has_command ('amavisd') ||
      &has_command ('amavis')
    )
  );
}

# clamav_is_mbox_format ( $ )
# IN: -
# OUT: TRUE if file is in mbox format
#
# Check if a given file is in mbox format
#
sub clamav_is_mbox_format ($)
{
  my $f = shift;

  return 0 if (! -f $f);

  my $h = new FileHandle ($f);
  my $folder_reader =
    new Mail::Mbox::MessageParser ({
      'file_name' => $f,
      'file_handle' => $h
    });

  return (!ref ($folder_reader)) ? 0 : 1;
}

# clamav_has_clamscan ()
# IN: -
# OUT: command path
#
# Check for clamscan or clamdscan
#
sub clamav_has_clamscan ()
{
  return (&has_command ('clamscan') || &has_command ('clamdscan'));
}

# clamav_check_systemd ()
# IN: -
# OUT: 1 if systemd exists on the host
#
# Check if systemd is available on the host
#
sub clamav_check_systemd ()
{
  return !system (&has_command('pidof').' systemd 2>&1 > /dev/null');
}

# clamav_check_config ()
# IN: -
# OUT: -
#
# check if the module config is ok. if not, display a warning
# and exit
# 
sub clamav_main_check_config
{
  my $ok = 0;
  my $msg = '';
  my $have_systemd = &clamav_check_systemd ();

  # Begin tests
  if (!&clamav_has_clamscan ())
  {
    $msg = $text{'MSG_CONFIG_ALERT_CLAMSCAN'};
  }
  elsif (!&has_command ('freshclam'))
  {
    $msg = $text{'MSG_CONFIG_ALERT_REFRESH'};
  }
  elsif (!&clamav_check_version ())
  {
     $msg = $text{'MSG_BAD_CLAMAV_VERSION'};
  }
  elsif ($config{'clamav_init_restore_path'} eq '' ||
         ! -d $config{'clamav_init_restore_path'} ||
         !&is_secure ($config{'clamav_init_restore_path'}))
  {
    $msg = $text{'MSG_CONFIG_ALERT_BACKUP_PATH'};
  }
  elsif ($config{'clamav_working_path'} eq '' ||
         !&is_secure ($config{'clamav_working_path'}))
  {
    $msg = $text{'MSG_CONFIG_ALERT_WORKING_PATH'};
  }
  elsif (!$have_systemd && ($config{'clamav_init_script'} eq '' || 
          !&clamav_file_is_executable ($config{'clamav_init_script'}) ||
          !&is_secure ($config{'clamav_init_script'})))
  {
    $msg = $text{'MSG_CONFIG_ALERT_CLAMAV_DAEMON'};
  }
  elsif ($config{'clamav_clamav_log'} eq '' ||
         ! -f $config{'clamav_clamav_log'} ||
         !&is_secure ($config{'clamav_clamav_log'}))
  {
    $msg = $text{'MSG_CONFIG_ALERT_CLAMAV_LOG'};
  }
  elsif ($config{'clamav_clamav_conf'} eq '' ||
         ! -f $config{'clamav_clamav_conf'} || 
         !&is_secure ($config{'clamav_clamav_conf'}))
  {
    $msg = $text{'MSG_CONFIG_ALERT_CLAMAV_CONF'};
  }
  elsif ($config{'clamav_db1'} eq '' ||
         ! -f &clamav_get_main_db_path () ||
         !&is_secure ($config{'clamav_db1'}))
  {
    $msg = $text{'MSG_CONFIG_ALERT_DB1'};
  }
  elsif ($config{'clamav_db2'} eq '' ||
         !&is_secure ($config{'clamav_db2'}))
  {
    $msg = $text{'MSG_CONFIG_ALERT_DB2'};
  }
  elsif ($config{'clamav_freshclam_log'} eq '' ||
         !&is_secure ($config{'clamav_freshclam_log'}))
  {
    $msg = $text{'MSG_CONFIG_ALERT_FRESHCLAM_LOG'};
  }
  elsif ($config{'clamav_refresh_use_cron'} == UP_DAEMON)
  {
    if ($config{'clamav_freshclam_conf'} eq '' ||
        ! -f $config{'clamav_freshclam_conf'} ||
        !&is_secure ($config{'clamav_freshclam_conf'}))
    {
      $msg = $text{'MSG_CONFIG_ALERT_FRESHCLAM_CONF'};
    }
    elsif (!$have_systemd && ($config{'clamav_freshclam_init_script'} eq '' ||
            !&clamav_file_is_executable (
               $config{'clamav_freshclam_init_script'}) ||
            !&is_secure ($config{'clamav_freshclam_init_script'})))
    {
      $msg = $text{'MSG_CONFIG_ALERT_FRESHCLAM_INIT'};
    }
    else
    {
      $ok = 1;
    }
  }
  elsif ($config{'clamav_freshclam_init_script'} ne '' &&
         $config{'clamav_freshclam_init_script'} eq
           $config{'clamav_init_script'})
  {
    $msg = $text{'MSG_CONFIG_ALERT_INIT_SCRIPTS_SAME'};
  }
  elsif ($config{'clamav_refresh_use_cron'} eq '')
  {
    $msg = $text{'MSG_CONFIG_ALERT_USE_CRON'};
  }
  else
  {
    $ok = 1;
  }

  # If there was a problem, exit displaying a message
  &clamav_check_config_exit ($msg) if (!$ok);

  &clamav_setup ();
}

# clamav_file_is_executable ( $ )
# IN: filename to check
# OUT: 1 if the file is executable
#
# Check if a file is executable. File can be a symbolic link to a executable 
# file.
#
sub clamav_file_is_executable ()
{
  my $f = shift;

  $f = readlink ("$f") if (-l "$f");

  return (-x "$f");
}

# clamav_setup ()
# IN: -
# OUT: -
#
# Create required dir/files and control their attributes
#
sub clamav_setup ()
{
  my $dir = '';

  $config{'clamav_spam_user'} = DEFAULT_CLAMAV_SPAM_USER
    if ($config{'clamav_spam_user'} eq '' ||
        !&is_secure ($config{'clamav_spam_user'}));

  $config{'clamav_sys_user'} = DEFAULT_CLAMAV_SYS_USER 
    if ($config{'clamav_sys_user'} eq '' ||
        !&is_secure ($config{'clamav_sys_user'}));

  $config{'clamav_sys_group'} = DEFAULT_CLAMAV_SYS_GROUP
    if ($config{'clamav_sys_group'} eq '' ||
        !&is_secure ($config{'clamav_sys_group'}));

  # Create module's temporary directory
  make_path (
    "$config{'clamav_working_path'}/.clamav/$remote_user",
    "$root_directory/$module_name/tmp",
    {'chmod' => 0700}
  );

  # Modify permissions
  system (&has_command('chmod')." 755 $root_directory/$module_name/bin/*");

  # Touch log files
  foreach my $l (($config{'clamav_clamav_log'}, 
                  $config{'clamav_freshclam_log'}))
  {
    next if (!$l || -f $l);

    open (H, '>', $l);close (H);
    chmod (0600, $l);
    chown (getpwnam($config{'clamav_sys_user'}),
           getgrnam($config{'clamav_sys_group'}), $l);
  }
}

# clamav_get_proxy_settings ()
# IN: -
# OUT: A array with 0="proxy server" and 1="proxy port"
#
# Load the proxy settings and return them
# 
sub clamav_get_proxy_settings
{
  &clamav_load_config ('freshclam');

  return 
    (
      $freshclam_config{'HTTPProxyServer'}->[0] &&
      $freshclam_config{'HTTPProxyPort'}->[0]
    ) ?
    (
      $freshclam_config{'HTTPProxyServer'}->[0],
      $freshclam_config{'HTTPProxyPort'}->[0]
    )
    :
    ();
}

# clamav_remote_actions_take_arg ( $ )
# IN: item to check
# OUT: 1 if command take arg, 0 if not
#
# Check if a remote command must take arg or not
#
sub clamav_remote_actions_take_arg ( $ )
{
  my $ra = shift;

  require "$root_directory/$module_name/data/clamav_remote_actions.pm";

  return $clamav_remote_actions{$ra};
}

# clamav_display_combo_quarantine_items_types ( $ )
# IN: item to select
# OUT: A buffer with the HTML combo code of a SELECT box
#
# Build a HTML select box and return its code
#
sub clamav_display_combo_quarantine_items_types ()
{
  my $selected = shift;
  my $buf = '';
  my %types = (
       $text{'VIRUSES'} => 'virus',
      $text{'SPAMS'} => 'spam'
     );

  if (&clamav_is_amavisd_new ())
  {
    $types{$text{'BADHEADERS'}} = 'badh';
    $types{$text{'BANNED'}} = 'banned';
  }

  $buf = qq(<select name="search_type">\n);
  foreach my $value (sort keys %types)
  {
    $buf .= sprintf (qq(<option value="%s"%s>%s</option>),
              $types{$value},
              ($types{$value} eq $selected) ? ' selected' : '',
              $value);
  }
  $buf .= qq(</select>\n);

  return $buf;
}

# clamav_display_combo_predefined ( $ )
# IN: - Type : C<clamav>, C<freshclam>
#     - C<1> if combo must not display values that already exist in the config
#       file
# OUT: 1 if combo box has been displayed (if there is result)
#
# Display a combo box with clamav or freshclam predefined variables
#
sub clamav_display_combo_predefined ( $ $ )
{
  my ($type, $uniq) = @_;
  my $buf = '';
  my %p;
  my %c;
  my $ok = 0;

  require "$root_directory/$module_name/data/${type}_predefined.pm";

  if ($type eq 'clamav')
  {
    %p = %clamav_predefined;
    %c = %clamav_config;
  }
  else
  {
    %p = %freshclam_predefined;
    %c = %freshclam_config;
  }
  
  $buf = qq(<select name="ns${type}_add_key">\n);
  foreach my $key (sort keys %p)
  {
    if (!defined ($c{$key}) || $p{$key} == 2)
    {
      $ok = 1;
      $buf .= qq(<option value="$key">$key</option>\n)
    }
  }
  $buf .= qq(</select>\n);

  # Only print if there is result
  print $buf if ($ok == 1);

  return $ok;
}

# clamav_quarantine_resend_check_config ()
# IN: -
# OUT: -
#
# Check if the config is ok for resending quarantined emails. 
# if not, display a warning and exit
# 
sub clamav_quarantine_resend_check_config
{
  if (!&has_command ('rsmtp') && !&has_command ('sendmail'))
  {
    &clamav_check_config_exit ($text{'MSG_CONFIG_ALERT_MTA'});
  }
}

# clamav_quarantine_main_check_config ()
# IN: -
# OUT: -
#
# Check if the config is ok for managing quarantined emails. 
# If not, display a warning and exit
#
sub clamav_quarantine_main_check_config
{
  my $ok = 0;
  my $msg = '';

  if (
    $config{'clamav_quarantine_soft'} == CS_NONE ||
    (
      !&clamav_is_amavisd_new () &&
      !&clamav_is_amavis_ng () &&
      !&clamav_is_milter () &&
      !&clamav_is_mailscanner () &&
      !&clamav_is_qmailscanner ()
    ))
  {
    $msg = qq(<p>$text{'MSG_CONFIG_ALERT_AMAVIS'}</p>);
  }
  elsif (
    $config{'clamav_quarantine'} eq '' ||
    ! -e $config{'clamav_quarantine'})
  {
    $msg = qq(<p>$text{'MSG_CONFIG_ALERT_QUARANTINE'}</p>);
  }
  elsif (length ($config{'clamav_quarantine'}) < 8)
  {
    $msg = sprintf (qq(<p>$text{'MSG_CONFIG_WARNING_QUARANTINE_TO_SHORT'}</p>),
             $config{'clamav_quarantine'});
  }
  else
  {
    $ok = 1;
  }

  &clamav_check_config_exit ($msg) if (!$ok);
}

# clamav_signatures_check_config ()
# IN: -
# OUT: -
#
# Check if the server config is ok for the signatures creation section. 
# if not, display a warning and exit
#
sub clamav_signatures_check_config
{
  &clamav_check_config_exit ($text{'MSG_ERROR_SIGNATURES_CONFIG'})
    if (
      !&has_command ('strings') ||
      !&has_command ('hexdump')
    );
}

# clamav_check_config_exit ( $ )
# IN: Message to display
# OUT: -
#
# Print a message and exit
# 
sub clamav_check_config_exit ( $ $ )
{
  my $msg = shift;
  my $main_page = shift;

  print qq(<p>$msg</p>) if ($msg);
  print qq(<hr>);
  if ($main_page)
  {
    &footer('/', $text{'index'});
  }
  else
  {
    &footer('', $text{'RETURN_INDEX_MODULE'});
  }

  exit (1);
}

# clamav_trim_config ()
# IN: -
# OUT: -
#
# Remove trailing and pending spaces from every module's
# config variable
# 
sub clamav_trim_config
{
  foreach my $key (keys %config)
  {
    $config{$key} =~ s/^\s+|\s+$//g;
  }
}

# clamav_get_uniq_id ()
# OUT: a numeric uniq id
#
# Build a numeric uniq id
#
sub clamav_get_uniq_id ()
{
  return time().int(rand(1000000));
}

# clamav_check_signature ( $ )
# IN: new virus signature
# OUT: A error message if the signature is not valid
#
# Check the ClamAV compatibility for a given virus signature
#      
sub clamav_check_signature ( $ )
{
  my $signature = shift;
  my $clamscan = &clamav_has_clamscan ();
  my $ret;

  if ($signature !~ /^[a-z0-9\._\-\/:]+$/i)
  {
    return $text{'MSG_ERROR_BAD_SIGNATURE'};
  }

  my $tmp_file = &tempname (&clamav_get_uniq_id().'.hdb');
  open (H, '>', $tmp_file); print H $signature; close (H);

  my $r = `$clamscan -d $tmp_file $tmp_file 2>&1`;
  if ($r =~ /rror\s*:\s*(.*)/)
  {
    $ret = $1;
  }

  unlink ($tmp_file);

  return $ret;
}

# clamav_build_signature ( $ )
# IN: hashref \%in
# OUT: SHA1 sum, filesize, name
#
# Build a SHA1 signature
#
sub clamav_build_signature ( $ )
{
  my $in = shift;
  my $sigtool = &has_command ('sigtool');
  my ($signature, $virus_name);
  my $id = &clamav_get_uniq_id();

  my $tmp_file = &tempname($id.$in->{'upload_filename'});
  open (H, '>', $tmp_file); print H $in->{'upload'}; close (H);

  my $r = `$sigtool --sha1 \Q$tmp_file`;
  unlink ($tmp_file);

  my ($a, $b, $c) = $r =~ /^([^:]+):([^:]+):([^\.]+)\.?/;

  $c =~ s/$id//;

  return ($a, $b, ucfirst($c));
}

# clamav_get_version ()
# IN: -
# OUT: clamav release
#
# Return the current installed clamav release
# 
sub clamav_get_version
{
  my $clamscan = &clamav_has_clamscan ();
  my $out = `$clamscan --version 2>&1`;

  return ($out =~ /devel-([\d+]{8})/ ||
          $out =~ /([\d,\.]+)/ ||
          $out =~ /ClamAV\s*([^\/]+)/) ? $1 : '';
}

# clamav_check_version ()
# IN: -
# OUT: boolean value
#
# Return true if the installed version of clamav
# is supported by this module. if this is a "stable" release, we look
# at its version number, otherwise if it is a development release we look at
# its date
# 
sub clamav_check_version
{
  my $ret = 0;
  my $clamscan = &clamav_has_clamscan ();
  my $out = `$clamscan --version 2>&1`;

  # Clamav devel
  if ($out =~ /devel-([\d+]{8})/)
  {
    $ret = (&Date_Cmp (SUPPORTED_DEVEL_DATE, $1) <= 0);
  }
  # Clamav package
  elsif ($out =~ /([\d\.]+)/ || $out =~ /ClamAV\s+([\d\.]+)/)
  {
    @local = split (/\./, $1);
    @ref = split (/\./, SUPPORTED_VERSION);

    $ret = ! (
        $local[0] < $ref[0]
        ||
        (
          exists ($local[1]) &&
          $local[0] == $ref[0] &&
          $local[1] < $ref[1]
        )
        ||
        (
          exists ($local[2]) &&
          $local[0] == $ref[0] &&
          $local[1] == $ref[1] &&
          $local[2] < $ref[2]
        )
      );
  }

  return $ret;
}

# clamav_get_runlevel ()
# IN: -
# OUT: the current runlevel
#
# Return the current runlevel of the server system
# 
sub clamav_get_runlevel
{
  my $runlevelc = &has_command ('runlevel');
  my $runlevel = `$runlevelc`;

  $runlevel =~ s/N //;
  $runlevel =~ s/^\s+|\s+$//g;
  $runlevel = int ($runlevel);

  return ($runlevel == 0) ? '' : $runlevel;
}

# clamav_get_freshclam_daemon_settings ()
# IN: -
# OUT: check period
#
# Return the check period specified in the configuration file of
# freshclam daemon
#
sub clamav_get_freshclam_daemon_settings
{
  &clamav_load_config ('freshclam');
  
  my $ret = $freshclam_config{'Checks'}->[0];

  return ($ret eq '') ? 1 : $ret;
}

# clamav_vdb_preprocess_inputs ( $ )
# IN: hashref user inputs
#
# Update user inputs if needed
#
sub clamav_vdb_preprocess_inputs ( $ )
{
  my $in = shift;

  return if ($in->{'prefix0'});

  require "$root_directory/$module_name/data/viruses_prefixes.pm";

  my $virus = $in->{'virus'}||'';
  my @r = split (/\./, $virus, 3);

  for (my $i = 0; $i < 2; $i++)
  {
    if ($r[$i])
    {
      $r[$i] = ucfirst (lc ($r[$i]));
      if (grep (/^$r[$i]$/, @{$viruses_prefixes[$i]}))
      {
        $in->{"prefix$i"} = $r[$i];
        $virus =~ s/$r[$i]\.?//i;
      }
    }
  }

  if ($in->{'prefix0'} && $in->{'prefix1'})
  {
    $in->{'virus'} = $virus;
  }
  else
  {
    $in->{'prefix0'} = $in->{'prefix1'} = '';
  }
}

# clamav_vdb_search ( $ )
# IN: script args
# OUT: -
#
# Do a search in ClamAV database and display the result
# 
sub clamav_vdb_search ( $ )
{
  my $in = shift;
  my $p1 = $in->{'prefix0'};
  my $p2 = $in->{'prefix1'};
  my $virus = $in->{'virus'};
  my $strict = ($in->{'strict'} eq 'on');
  my $case = ($in->{'case'} eq 'on');
  my $sortr = ($in->{'sort'} eq 'on');
  my $string = '';
  my $first = 1;
  my $grep = &has_command('grep');

  return if (
    $p1 && $p1 !~ /^[a-z]+$/i ||
    $p2 && $p2 !~ /^[a-z]+$/i ||
    $virus && ($virus !~ /^[a-z0-9\._\-\/:]+$/i || $virus =~ /^[\s\.]+$/)
  );

  if ($p1)
  {
    $p1 .= ".$p2" if ($p2);
    $virus = ($virus) ? "$p1.$virus" : $p1;
  }

  # Case sensitive search?
  $case = ($case) ? ' ' : ' -i ';

  # Sort results
  $sortr = ($sortr) ? ' '.&has_command('sort').' |' : '';
  
  # Strict check (exact match)?
  $string = ($virus ne '') ? 
    (($strict) ? 
      &has_command('sigtool').
        " --list-sigs | $grep $case \"^$virus\$\" | $sortr" :
      &has_command('sigtool').
        " --list-sigs | $grep $case $virus | $sortr") :
        &has_command('sigtool')." --list-sigs | $sortr";

  # Display results
  open (H, $string);
  while (<H>)
  {
    next if (/^ERROR/);

    if ($first)
    {
      $first = 0;
      print qq(<table border=1><tr $tb><th>$text{'NAME'}</th></tr>);
    }
      
    print qq(<tr><td $cb>$_</td></tr>);
  }
  close (H);
  
  if (!$first)
  {
    print qq(</table>);
  }
  else
  {
    printf qq(<p>$text{'NO_RESULT'}</p>), $virus;
  }
}

# clamav_get_db_viruses_count ()
# IN: -
# OUT: Number of viruses in ClamAV database
#
# Count the number of viruses in ClamAV databases and return it
# 
sub clamav_get_db_viruses_count
{
  my $sigtool = &has_command ('sigtool');
  my $wc = &has_command ('wc');
  my $count = `$sigtool --list-sigs | $wc -l`;
  
  $count =~ s/\s//g;
  
  return $count;
}

# clamav_display_combos_viruses_prefixes ()
# IN: 1 if combo must not display values that already exist
#     in the config file
# OUT: 1 if combo box has been displayed (if there is result)
#
# Display a combo box with freshclam predefined variables
#
sub clamav_display_combos_viruses_prefixes ()
{
  my @defaults = @_;
  my $display1 = ($defaults[0]) ? 'inline-block':'none';
  my $ret = '';

  require "$root_directory/$module_name/data/viruses_prefixes.pm";

  for (my $i = 0; $i < 2; $i++)
  {
    my $default = $defaults[$i]||'';

    $ret .= ($i == 0) ?
      qq(<select name="prefix$i" onchange="(this.selectedIndex) ? getElementById('prefix1').style.display='inline-block':getElementById('prefix1').style.display='none'">\n)
      :
      qq(<select id="prefix$i" name="prefix$i" style="display:$display1">\n);
    $ret .= '<option value="">Choose prefix '.($i + 1).'</option>'."\n";
    foreach my $p (@{$viruses_prefixes[$i]})
    {
      $ret .=
        '<option value="'.$p.'"'.
        (($default eq $p)?' selected="selected"':'').'>'.$p.'</option>'."\n";
    }
    $ret .= qq(</select>\n);
  }

  return $ret;
}

# clamav_get_freshclam_daemon_state ()
# IN: -
# OUT: true if the freshclam daemon is deactivated
#
# Return the actual state of the freshclam daemon service
# 
sub clamav_get_freshclam_daemon_state
{
  my $ret;

  if (&clamav_check_systemd ())
  {
    $ret = &daemon_control_systemd ('freshclam', 'status');
  }
  else
  {
    $ret = ($gconfig{'os_type'} =~ /bsd/) ?
      (&clamav_bsd_get_state ('freshclam') eq 'YES') : 
      (&find_byname ('freshclam'));
  }

  return $ret;
}

# clamav_bsd_get_state ( $ )
# IN: daemon name (clamav or freshclam)
# OUT: system setting for the daemon (NO or YES)
#
# Return the current system setting for a given daemon for BSD systems
# 
sub clamav_bsd_get_state ( $ )
{
  my $daemon = shift;
  my $ret = 'NO';

  open (H, '<', '/etc/rc.conf');
  while (my $line = <H>)
  {
    if ($line =~ /clamav_${daemon}_enable/)
    {
      chop ($line);
      $ret = (split (/=/, $line))[1];
      $ret =~ s/"//g;
    }
  }
  close (H);

  return uc ($ret);
}

# clamav_verif_refresh_method_ok ()
# IN: -
# OUT: ER_DAEMON_NOEXIST
#        Config say to use a daemon but no daemon exist on the system
#      ER_DAEMON_CRONEXIST
#        Config say to use a daemon, but a cron exist on the system
#      ER_CRON_DAEMONEXIST
#        Config say tu use cron, but a daemon exist on the system
#      OK
#        Config and system are ok
#
# Check if the refresh method choose by user in module config is
# ok according to the system
# 
sub clamav_verif_refresh_method_ok
{
  my $runlevel = '';
  my $freshclam = '';
  my $freshclambase = '';
  my $link = '';
  my $use_cron = 0;
  my $bsd_clam_state = 'NO';
  my $grep = &has_command ('grep');
  my $method = $config{'clamav_refresh_use_cron'};
  my $test = 0;
  my $have_systemd = &clamav_check_systemd ();
  
  $runlevel = &clamav_get_runlevel ();
  $freshclam = $config{'clamav_freshclam_init_script'};
  $freshclambase = basename ($freshclam);
  $bsd_clam_state = &clamav_bsd_get_state ('freshclam')
    if ($gconfig{'os_type'} =~ /bsd/);

  $test = `$grep wbmclamav $freshclam`;
  
  if ($method == UP_MANUAL)
  {
    return ER_MANUAL_CRONEXIST if (
      -f "/etc/cron.d/clamav-freshclam" ||
      &clamav_get_cron_settings ('update')
    );

    if ($have_systemd)
    {
      return ER_MANUAL_DAEMONEXIST if
        (
          &daemon_control_systemd ('freshclam', 'status')
        );
    }
    else
    {
      return ER_MANUAL_DAEMONEXIST if
        (
          -e "$freshclam" &&
          !$test &&
          ! -f "/etc/cron.d/clamav-freshclam"
        );
    }
  }
  elsif ($method == UP_DAEMON)
  {
    return ER_DAEMON_CRONEXIST if
      (-f "/etc/cron.d/clamav-freshclam" ||
       &clamav_get_cron_settings('update'));

    if ($have_systemd)
    {
      ##FIXME
      ;
    }
    else
    {
      # If problem with sysvinit
      return ER_DAEMON_NOEXIST if (! -e "$freshclam");
    }
  }
  elsif ($method == UP_CRON)
  {
    return ER_CRON_DAEMONEXIST if (
      -e "$freshclam" &&
      !$test &&
      ! -f "/etc/cron.d/clamav-freshclam"
    );
  }

  return OK;
}

# clamav_scandir ( $ $ $ $ )
# IN: directory to scan
#     flag to indicate to use or not recursivity
#     flag to indicate to only show infected files or all
#     directory where to put infected files
# OUT: -
#
# Check a given directory and display freshclam output on the current web page
# 
sub clamav_scandir ( $ $ $ $ )
{
  my ($dir, $recursive, $infected_only, $move_path) = @_;
  my $clamscan = &clamav_has_clamscan ();
  my $report = 0;
  my $infected = 0;
  my $move_path_option = '';
  my $recursive_option = ($clamscan !~ /clamdscan/ && $recursive) ? ' -r ' : '';
  my $tmp_file = '';

  return if (!&is_secure ("$move_path $recursive_option $dir"));
      
  $dir =~ s/\/+/\//g;
  $dir = "\"$dir\"";
  if ($move_path)
  {
    $move_path =~ s/\/+/\//g;
    $move_path_option = " --move \"$move_path\"";
  }

  print qq(
    <table border=0 width="90%">
    <tr><td $tb align="center"><b>$text{'CLAMSCAN_COMMAND'}:</b> <code>$clamscan $move_path_option $recursive_option $dir</code></td></tr>
    <tr><td valign="top" align="center">
  );
  print qq(<table border=0>);

  open (H, "$clamscan $move_path_option $recursive_option $dir 2>&1 |");
  while (<H>)
  {
    my ($file, $state) = split (/:/, $_, 2);
    next if (!$file || !$state);

    my $state_bg = '';
    my $right = '&nbsp;';
    my $is_infected = 0;

    if ($state =~ /OK/)
    {
      $state_bg = 'green';
      $state = '&nbsp;';
    }
    elsif ($state =~ /FOUND/)
    {
      $infected++;
      $is_infected = 1;
      $state_bg = 'red';
      $state =~ s/FOUND//g;
      $state = qq(<b>$state</b>);
      if ($move_path)
      {
        $tmp_file = $move_path.basename($file);
        $right = 
          qq(<input type="checkbox" 
	            name="infected_file$infected" value="$tmp_file">);
      }
      else
      {
        $right = 
          qq(<input type="checkbox" 
	            name="infected_file$infected" value="$file">);
      }
    }
    
    if (($file =~ /known viruses/i) && ($report == 0))
    {
      $report = 1;
      
      print qq(
        <tr><td colspan="3">&nbsp;</td></tr>
        <tr><td colspan="3" align="center">
          <input type="submit" value="$text{'DELETE_SELECTED'}" name="delete">
        </td></tr>
      ) if (&clamav_get_acl ('directories_check_delete') == 1 && $infected > 0);

      print qq(</table>);
      print qq(<table border=0 cellspacing=2 cellpadding=2 width="100%">);
      print qq(<tr><td colspan="3">&nbsp;</td></tr>);
      print qq(<tr><th colspan="3" $cb>Report</th></tr>);
      print qq(<tr><td colspan="3">&nbsp;</td></tr>);
      if ($move_path && $infected)
      {
        print qq(
          <tr><td align="right" width="50%">
	  <b>$text{'INFECTED_FILES_WHERE_MOVED'}</b>:</td>
	  <td colspan="2" align="left" width="50%">$move_path</td></tr>
        );
      }
    }
    
    if (!$report)
    {
      if ((!$is_infected && $infected_only) || $state =~ /moved to/) {}
      else
      {
        print qq(<tr><td $cb>$file</td>);

	if (&clamav_get_acl ('directories_check_delete') == 1)
	  {print qq(<td bgcolor="$state_bg">$state</td><td>$right</td></tr>)}
	else
	  {print qq(<td bgcolor="$state_bg">$state</td></tr>)}
      }
    }
    else
    {
      my $oldfile = $file;
      $file =~ tr/a-z/A-Z/;
      $file =~ s/ /_/g;
      $text{$file} = $oldfile if (!exists ($text{$file}));
      print qq(
        <tr><td align="right" width="50%"><b>$text{$file}</b>:</td>
	<td colspan="2" align="left" width="50%">$state</td></tr>
      );
    }
  }
  print qq(</table>) if ($report);
  print qq(</td></tr></table>);
  
  close (H);
}

# clamav_get_main_db_path ()
# IN: -
# OUT: main database
#
# Return the full path/name of the main database
#
sub clamav_get_main_db_path
{
  my $datadir = dirname ($config{'clamav_db1'});
  return (-f "$datadir/main.cld") ? "$datadir/main.cld" : "$datadir/main.cvd";
}

# clamav_get_daily_db_path ()
# IN: -
# OUT: daily database
#
# Return the full path/name of the daily database
#
sub clamav_get_daily_db_path
{
  my $datadir = dirname ($config{'clamav_db2'});
  return 
    (-f "$datadir/daily.cld") ? "$datadir/daily.cld" : "$datadir/daily.cvd";
}

# clamav_get_last_db_update ()
# IN: -
# OUT: a array with main and daily db update date
#
# Check the signatures databases dates and return them in a
# array
# 
sub clamav_get_last_db_update
{
  my $main = '';
  my $main_infos = '';
  my $daily = '';
  my $daily_infos = '';
  my $maindb = clamav_get_main_db_path ();
  my $dailydb = clamav_get_daily_db_path ();
         
  if (-f $maindb)
  {
    $main = &make_date ((stat($maindb))[9]);
    open (H, &has_command ('sigtool')." --info $maindb 2>&1 |");
    while (<H>)
    {
      chomp ();
      my ($name, $value) = split (/:/);
      $main_infos .= "$text{$name}: <b>$value</b>" if ($name eq 'Version');
      $main_infos .= " - $text{$name}: <b>$value</b>" 
        if ($name eq 'Functionality level');
    }
    close (H);
  }

  if (-f $dailydb)
  {
    $daily = &make_date ((stat($dailydb))[9]);
    open (H, &has_command ('sigtool')." --info $dailydb 2>&1 |");
    while (<H>)
    {
      chomp ();
      my ($name, $value) = split (/:/);
      $daily_infos .= "$text{$name}: <b>$value</b>" if ($name eq 'Version');
      $daily_infos .= " - $text{$name}: <b>$value</b>"
        if ($name eq 'Functionality level');
    }
    close (H);
  }

  return ($main, $daily, $main_infos, $daily_infos);
}

# clamav_is_a_script ( $ )
# IN: The file to check
# OUT: True if the file is a script
#
# Check if a given file is a script.
# 
sub clamav_is_a_script
{
  my $file = shift;
  my $filec = &has_command ('file');
  my $res = `$filec $file`;

  return ($res =~ /script/);
}

# clamav_deactivate_system_file ( $ )
# IN: The file to reactivate
# OUT: -
#
# Deactivate a system script.
#
# This is pretty bad and dirty, so if
# you have a better idea on how to proceed, send me a E-Mail :-)
#
sub clamav_deactivate_system_file
{
  my $file = shift;
  my $perl = &has_command ('perl');

  return if (!(-f $file) || !&clamav_is_a_script ($file));

  `$perl -pi -e 's/^([^#])/#deactivated by wbmclamav#\$1/g' $file`;
}

# clamav_reactivate_system_file ( $ )
# IN: The file to reactivate
# OUT: -
#
# Reactivate a system script previously deactivated with
# "clamav_deactivate_system_file ()". 
#
# This is pretty bad and dirty, so if
# you have a better idea on how to proceed, send me a E-Mail :-)
# 
sub clamav_reactivate_system_file
{
  my $file = shift;
  my $perl = &has_command ('perl');

  return if (! -f $file);

  `$perl -pi -e 's/^#deactivated by wbmclamav#//g' $file`;
}

# clamav_set_db_no_autoupdate ()
# IN: -
# OUT: -
#
# If user choose to not automatically update db, we stop clamd and
# deactivate cron and services
# 
sub clamav_set_db_no_autoupdate
{
  my $freshclam = '';
  my $freshclambase = '';

  if (&clamav_check_systemd ())
  {
    &daemon_control_systemd ('freshclam', 'stop');
    &daemon_control_systemd ('freshclam', 'disable');
  }
  else
  {
    $freshclam = $config{'clamav_freshclam_init_script'};
    $freshclambase = basename ($freshclam);
  
    if ($gconfig{'os_type'} =~ /bsd/)
    {
      &daemon_control ($freshclam, "stop");
      &clamav_bsd_update_state ('freshclam', 'NO');
    }
    else
    {
      &clamav_reactivate_system_file ($freshclam);
      &daemon_control ($freshclam, "stop");
      &clamav_deactivate_system_file ($freshclam);
    }
  }

  &clamav_delete_cron ('update');

  return 1;
}

# clamav_bsd_update_state ( $ $ )
# IN: daemon name (freshclam or clamav)
#     state (YES or NO)
# OUT: -
#
# Set the system state for a given daemon on BSD systems
# 
sub clamav_bsd_update_state ( $ $ )
{
  my ($daemon, $state) = @_;
  my $found = 0;

  copy ('/etc/rc.conf', '/etc/rc.conf_wbmclamav');

  open (SRC, '<', '/etc/rc.conf_wbmclamav');
  open (DST, '>', '/etc/rc.conf');

  while (my $line = <SRC>)
  {
    if ($line =~ /clamav_${daemon}_enable/)
    {
      $line = "clamav_${daemon}_enable=\"$state\"\n";
      $found = 1;
    }

    print DST $line;
  }

  print DST "clamav_${daemon}_enable=\"$state\"\n" if (!$found);

  close (DST);
  close (SRC);
}

sub clamav_get_cron_path ()
{
  return (-d '/etc/cron.d/') ? CRONTAB_MODULE_PATH : CRONTAB_PATH;
}

# clamav_delete_cron ( $ )
# IN: type of the cron (purge|update)
# OUT: -
#
# Delete the line associated with the given type in
# /etc/cron.d/webmin_clamav or /etc/crontab
# 
sub clamav_delete_cron ( $ )
{
  my $type = shift;
  my $path = '';
  my $path_sav = '';

  $path = &clamav_get_cron_path ();
  $path_sav = "$path.sav";

  # First time, make a backup of the original 
  # crontab file
  copy ($path, "$path.orig-wbmclamav") if (! -f $path_sav);
  copy ($path, $path_sav);

  open (SRC, '<', $path_sav);
  open (DST, '>', $path); 
  while (my $line = <SRC>)
  {
    print DST $line
      if ($line !~ /^.*#.*$type/);
  }
  close (DST);
  close (SRC);

  unlink ($path_sav);
}

# clamav_set_freshclam_daemon_settings ( $ $ )
# IN: old frequency, new frequency
# OUT: -
#
# Update the check interval frequency of the refresh for the
# freshclam daemon and restart it
# 
sub clamav_set_freshclam_daemon_settings ( $ $ )
{
  my ($oldfreq, $freq) = @_;
  my $freshclam = '';
  my $freshclambase = '';
  my $have_systemd = &clamav_check_systemd ();

  $freshclam = $config{'clamav_freshclam_init_script'};
  $freshclambase = basename ($freshclam);

  if ($have_systemd)
  {
    &daemon_control_systemd ('freshclam', 'enable');
    &daemon_control_systemd ('freshclam', 'start');
  }
  elsif ($gconfig{'os_type'} =~ /bsd/)
  {
    &clamav_bsd_update_state ('freshclam', 'YES');
    &daemon_control ($config{'clamav_freshclam_init_script'}, "start");
  }
  else
  {
    &clamav_reactivate_system_file ($freshclam);
  }
 
  &clamav_load_config ('freshclam');
  $freshclam_config{'Checks'} = [$freq];
  &clamav_save_freshclam_config ();

  if ($have_systemd)
  {
    &daemon_control_systemd ('freshclam', 'restart');
  }
  else
  {
    &daemon_control ($freshclam, 'restart');
  }

  if (!&clamav_get_freshclam_daemon_state ())
  {
    &clamav_set_db_no_autoupdate ();
    return 0;
  }

  return 1;
}

# daemon_control_systemd ( $ $ )
# IN: daemon to execute, command to pass
# OUT: 1 if OK
#
# Control a daemon with systemd
# 
sub daemon_control_systemd
{
  my ($type, $op) = @_;

  my $ret =
    !system (&has_command('systemctl')." $op clamav-$type 2>&1 > /dev/null");

  sleep (1);

  return $ret;
}

# daemon_control ( $ $ )
# IN: daemon to execute, command to pass
# OUT: -
#
# Control a daemon
# 
sub daemon_control
{
  my ($bin, $op) = @_;

  if ($op eq 'restart')
  {
    #&daemon_control ($bin, "stop");
    #&daemon_control ($bin, "start");
    system ($bin, 'restart')
  }
  else
  {
    system ($bin, $op);
  }

  sleep (1);
}

# clamav_save_freshclam_config ()
# IN: -
# OUT: -
#
# Save the freshclam configuration in freshclam config file
# 
sub clamav_save_freshclam_config
{
  require "$root_directory/$module_name/data/freshclam_predefined.pm";

  $fc = $config{'clamav_freshclam_conf'};

  # Backup config before
  copy ($fc, "$fc.clamav-backup");

  &lock_file ($fc);

  open (H, '>', $fc);
  foreach my $key (sort keys %freshclam_config)
  {
    foreach my $v (@{$freshclam_config{$key}})
    {
      next if ($v eq "$text{'UNDEFINED'}" ||
               $v eq '' && ($freshclam_predefined{$key} == 1 ||
                            $freshclam_predefined{$key} == 2));

      # If key does not accept argument -> boolean
      if ($freshclam_predefined{$key} == 0)
      {
        $v = ($v =~ /^(true|1|on|yes|t|y)$/i) ? 'true' : 'false';
      }

      foreach (split (/ /, $v))
      {
        print H "$key $_\n";
      }
    }
  }
  close (H);

  &unlock_file ($fc);
}

# clamav_save_global_settings ()
# IN: -
# OUT: -
#
# Save ClamAV/Freshclam settings in config files
# 
sub clamav_save_global_settings
{
  my $restart = shift;
  my $cc = '';
  my $fc = '';
  my $buf = '';

  require "$root_directory/$module_name/data/freshclam_predefined.pm";
  require "$root_directory/$module_name/data/clamav_predefined.pm";

  my %predefined = (
       'clamav' => {
         'keys' => \%clamav_predefined,
         'fh' => undef
       },
       'freshclam' => {
         'keys' => \%freshclam_predefined,
         'fh' => undef
       }
     );

  if (!$restart)
  {
    $cc = "$config{'clamav_working_path'}/.clamav/$remote_user/clamav.conf";
    $fc = "$config{'clamav_working_path'}/.clamav/$remote_user/freshclam.conf";
  }
  else
  {
    $cc = $config{'clamav_clamav_conf'};
    $fc = $config{'clamav_freshclam_conf'};

    # Backup configs before
    copy ($cc, "$cc.clamav-backup");
    copy ($fc, "$fc.clamav-backup");
  }

  &lock_file ($cc); open ($predefined{'clamav'}->{'fh'}, '>', $cc);
  &lock_file ($fc); open ($predefined{'freshclam'}->{'fh'}, '>', $fc);
  
  foreach my $key (sort keys %in)
  {
    next if ($key !~ /^(clamav|freshclam)_([a-z0-9]+)/i);

    my ($type, $k) = ($1, $2);
    my %h = %{$predefined{$type}{'keys'}};

    foreach $val (split (chr (0), $in{$key}))
    {
      next if ($restart &&
        (
          $val eq "$text{'UNDEFINED'}" ||
          $val eq '' && ($h{$k} == 1 || $h{$k} == 2)
        ));

      # If key does not accept argument -> boolean
      if ($h{$k} == 0)
      {
        $val = ($val =~ /^(true|1|on|yes|t|y)$/i) ? 'true' : 'false';
      }
  
      foreach (split (/ /, $val))
      {
        print {$predefined{$type}->{'fh'}} "$k $_\n";
      }
    }
  }
  
  close ($predefined{'freshclam'}->{'fh'}); &unlock_file ($fc);
  close ($predefined{'clamav'}->{'fh'}); &unlock_file ($cc);

  # Check if settings are ok
  $error = &clamav_check_global_settings ();

  if (!$error)
  {
    if ($restart)
    {
      &clamav_activate_clamd ();
      
      if ($config{'clamav_refresh_use_cron'} == UP_DAEMON)
      {
        &daemon_control ($config{'clamav_freshclam_init_script'}, 'restart');
      }

      &clamav_clean_global_settings_tempfiles ();
    }
  }
  # Something goes wrong with the conf
  else
  {
    # Restore backups
    copy ("$cc.clamav-backup", $cc);
    copy ("$fc.clamav-backup", $fc);
  }

  return $error;
}

# clamav_check_global_settings ()
# IN: -
# OUT: HTML to display if errors.
#
# Check if settings are ok. On errors, return HTML code to display on page.
#
sub clamav_check_global_settings ()
{
  my $clamconf = &has_command ('clamconf');
  my $buf = '';

  return if (!$clamconf);

  open (H, "$clamconf 2>&1 |");
  while (<H>)
  {
    if (/ERROR:\s*([^:]*):\s*(.*)$/)
    {
      my ($error, $description) = ($1, $2);
      $description =~ s/Option\s*([^ ]*)/Option <b>$1<\/b>/i;
      $buf .= qq(<tr><td $cb>$error</td><td>$description</td></tr>);
    }
  }
  close (H);

  if ($buf)
  {
    $buf = qq(
      <table border="1">
      <tr $tb><th>Error</th><th>Description</th></tr>
      $buf
      </table>
    );
  }

  return $buf;
}

# clamav_global_settings_get_delete_item ()
# IN: Type of item to process ('clamav' or 'freshclam')
# OUT: Keys of the item to delete (clamav predefine variable name)
#
# Return the name of the predefined variable to delete in clamav or
# freshclam's config file
# 
sub clamav_global_settings_get_delete_item
{
  my $type = shift;
  my $exp = 'ns'.$type.'_delete_';

  while (my ($k, $v) = each (%in))
  {
    return $k if ($k =~ s/^$exp//);
  }
}

# clamav_clean_global_settings_tempfiles ()
# IN: -
# OUT: -
#
# Remove temporary files for global settings section
# 
sub clamav_clean_global_settings_tempfiles
{
  unlink ("$config{'clamav_working_path'}/.clamav/$remote_user/clamav.conf");
  unlink ("$config{'clamav_working_path'}/.clamav/$remote_user/freshclam.conf");
}

# clamav_display_settings ()
# IN: - Type : C<clamav> or C<freshclam>
#     - Key to add (optional)
#     - Key to delete (optional)
# OUT: -
#
# Load clamav or freshclam configuration file and display it
# 
sub clamav_display_settings
{
  my ($type, $newkey, $deletekey) = @_;
  my $key = '';
  my %p;
  my $c;

  &clamav_load_config ($type);

  require "$root_directory/$module_name/data/${type}_predefined.pm";

  if ($type eq 'clamav')
  {
    %p = %clamav_predefined;
    $c = \%clamav_config;
  }
  else
  {
    %p = %freshclam_predefined;
    $c = \%freshclam_config;
  }
  
  if ($deletekey || $newkey)
  {
    # Delete a simple value key
    if (exists ($p{$deletekey}))
    {
      delete $in{$type."_$deletekey\[\]"} if ($deletekey);
    }
    # Delete multiple values key
    else
    {
      $deletekey =~ /^(.*)_(\d+)$/;
      my ($name, $todelete) = ($1, $2);
      my @a = split (chr (0), $in{$type."_$name\[\]"});
      splice (@a, $todelete, 1);
      $in{$type."_$name\[\]"} = join (chr (0), @a);
    }

    # Add a new key in the config file
    if ($newkey)
    {
      # Add multiple values key
      if ($p{$newkey} == 2)
      {
        my @a = split (chr (0), $in{$type."_$newkey\[\]"});
        push (@a, $text{'UNDEFINED'});
        $in{$type."_$newkey\[\]"} = join (chr (0), @a);
      }
      # Add a simple value key
      else
      {
        $in{$type."_$newkey\[\]"} =
          ($p{$newkey} == 1) ? "$text{'UNDEFINED'}" : ' ';
      }
    }
    
    # Save and reload config
    &clamav_save_global_settings (0);
    &clamav_load_config ($type);
  }

  if (&clamav_get_acl ('global_settings_write') == 1 &&
    &clamav_display_combo_predefined ($type, 1) == 1)
  {
    print qq( 
      <input type="submit" name="ns${type}_add" value="$text{'ADD_KEY'}">
    );
  }

  print qq(<table border=1>);
  foreach $key (sort keys %$c)
  {
    next if ($key eq '');
   
    $i = 0;

    foreach $val (@{$c->{$key}})
    {
      if ($val eq '')
      {
        print qq(
          <tr><td $cb>$key</td>
          <input type="hidden" name="${type}_$key\[\]">
  	<td><font color="silver"><i>$text{'NO_VALUE'}</i></font></td>
        );
      }
      elsif ($key eq $newkey || $val eq "$text{'UNDEFINED'}")
      {
        printf (qq(
          <tr><td bgcolor="gray"><font color="white"><b>$key</b></font></td>
          <td><input type="text" name="${type}_$key\[\]" size=40
          value="%s"></td>), &clamav_html_encode ($val));
      }
      else
      {
        printf (qq(
          <tr><td $cb>$key</td>
          <td><input type="text" name="${type}_$key\[\]" size=40
          value="%s"></td>), &clamav_html_encode ($val));
      }

      if (&clamav_get_acl ('global_settings_write') == 1)
      {
        my $endkey = '';
        if ($p{$key} == 2)
        {
          $endkey = "_$i";
          ++$i;
        }
        print qq(
          <td><input title="$text{'DELETE_ITEM'}" type="submit"
          name="ns${type}_delete_$key$endkey"
          value="$text{'DELETE'}"></td>
          </tr>
        );
      }
    }
  }
  print qq(</table>);
}

# clamav_load_config ()
# IN: - Type : C<clamav> or C<freshclam>
# OUT: -
#
# Load the clamav or freshclam config file in memory
# 
sub clamav_load_config
{
  my $type = shift;
  my $path = '';
  my $c;
    
  if ($type eq 'clamav')
  {
    %clamav_config = ();
    $c = \%clamav_config;
  }
  else
  {
    %freshclam_config = ();
    $c = \%freshclam_config;
  }
  
  $path =
    (-f "$config{'clamav_working_path'}/.clamav/$remote_user/$type.conf")?
      "$config{'clamav_working_path'}/.clamav/$remote_user/$type.conf":
      $config{'clamav_'.$type.'_conf'};
  
  open (H, '<', $path);
  while (my $l = <H>)
  {
    next if $l =~ /^(\s*#|\n)/;

    $l =~ s/#.*$//g;

    my ($key, @value) = split (/\s+/, $l);

    push (@{$c->{$key}}, join (' ', @value));
  }

  close (H);
}

# clamav_set_cron_update ( $ $ )
# IN: cron hour, cron day
# OUT: -
#
# Set the cron line for the db refresh in /etc/cron.d/webmin_clamav
# 
sub clamav_set_cron_update ( $ $ )
{
  my ($hour, $day) = @_;
  my $new_line = '';
  my $datadir = '';
  my $path = '';
  my $freshclam = &has_command ('freshclam');

  $path = &clamav_get_cron_path ();

  $datadir = dirname ($config{'clamav_db1'});

  $day = '*' if ($day == 7);
  &clamav_delete_cron ('update');
  $new_line = 
    "0 $hour * * $day root \$($freshclam " .
    "--quiet " .
    "--config-file $config{'clamav_freshclam_conf'} " .
    "--log $config{'clamav_freshclam_log'} " .
    "--datadir $datadir) " .
    "#update";

  open (H, '>>', $path);
  print H "$new_line\n";
  close (H);
}

# clamav_get_logfiles ()
# IN: -
# OUT: A array with logfiles
#
# Identify ClamAV log files and fill a array with them
#
sub clamav_get_logfiles
{
  my @ret = ();

  foreach my $key (%config)
  {
    push @ret, $key if ($key =~ /^.*\.log$/);
  }

  return @ret;
}

# clamav_set_cron_purge ( $ $ )
# IN: cron hour, cron day
# OUT: -
#
# Set cron line for the quarantine repository purge
# 
sub clamav_set_cron_purge ( $ $ )
{
  my ($hour, $day, $maxdays) = @_;
  my $new_line = '';
  my $path = '';

  $path = &clamav_get_cron_path ();

  $day = '*' if ($day == 7);
  &clamav_delete_cron ('purge');

  $new_line =
    "0 $hour * * $day root \$($root_directory/$module_name/bin/purge_quarantine " .
    " $config{'clamav_quarantine'} " .
    " $maxdays" .
    ") #purge";

  open (H, '>>', $path);
  print H "$new_line\n";
  close (H);
}

# clamav_update_db ()
# IN: -
# OUT: -
#
# Update virus signatures databases displaying output on the current web page
# 
sub clamav_update_db
{
  print qq(<div><pre style="background: #cccccc">);;
  open (H, &has_command ('freshclam').' 2>&1 |');
  while (<H>)
  {
    s/^*\n$/<br>/g;
    if (/load/) {print '.'} else {print};
  }
  close (H);
  print qq(</pre>);
}

# clamav_get_cron_settings ( $ )
# IN: type of the cron (purge|update)
# OUT: a array representing a cron line
#
# Return a array of a cron line corresponding to the given type. if line
# is not found, return undef
# 
sub clamav_get_cron_settings ( $ )
{
  my $type = shift;
  my @lines = ();
  my @cron_line = ();
  my @tmp = ();
  my $path = '';

  $path = &clamav_get_cron_path ();

  return undef if (! -e "$path");

  open (H, '<', $path);
  @lines = <H>;
  close (H);
                                                                                
  foreach (@lines)
  {
    @tmp = split (/#/, $_);
    $tmp[0] =~ s/[\$,(,)]+//g;
    @cron_line = split (/\s+/, $tmp[0]);

    return @cron_line
      if ($tmp[1] =~ /$type/);
  }
                                                                                
  return undef;
}

# clamav_freshclam_daemon_settings_table ( $ )
# IN: frequency
# OUT: a buffer to display
#
# Build a HTML table with all possible frequencies for freshclam daemon
# 
sub clamav_freshclam_daemon_settings_table ( $ )
{
  my $freq = shift;
  my $buffer = '';

  $buffer .= qq(
    <table border="1">
    <tr $tb><td><b>$text{'FREQUENCY'}</b></td></tr>
    <tr $cb>
    <td><select name="freq">
  );

  foreach my $f (1..50)
  {
    my $default = ($f == $freq) ? ' selected="selected"' : '';
    $buffer .= qq(<option value="$f"$default>$f</option>\n);
  }

  $buffer .= qq(</select></td></tr></table>);

  return $buffer;
}

# clamav_cron_settings_table ( $ $ )
# IN: default cron hour, default cron day
# OUT: a buffer to display
#
# Build a HTML table for choose hour a day for execution of refresh db cron
#
sub clamav_cron_settings_table
{
  my ($hour, $day) = @_;
  my $buffer = '';
  my $default = '';
  my $every_hour = '';

  require "$root_directory/$module_name/data/days.pm";

  ($every_hour, $hour) = split (/\//, $hour);
  ($every_hour, $hour) = ($hour, $every_hour) if (!$hour);
  
  $default = ($every_hour) ? ' checked="checked"' : '';
  $buffer .= qq(
    <table border="1">
    <tr $tb><td><b>$text{'HOUR'}</b></td><td><b>$text{'DAY'}</b></td></tr>
    <tr $cb><td valign="bottom">
    <small><i><input id="every_hours" type="checkbox" name="every_hours"$default>&nbsp;<label for="every_hours">$text{'EVERY_X_HOURS'}</label></i></small><br><select name="hour">
  );

  foreach (0..23)
  {
    $default = ($_ == $hour) ? ' selected="selected"' : '';
    $buffer .= qq(<option value="$_"$default>$_</option>\n);
  }

  $buffer .= qq(</select></td><td valign="bottom"><select name="day">);

  $day = 7 if ($day eq '*');
  $default = ($day == 7) ? ' selected="selected"' : '';
  $buffer .= qq(<option value="7"$default>$text{'EVERYDAY'}</option>\n);
  for (my $i = 0; $i < 7; $i++)
  {
    my $value = $days[$i];
    my $default = ($i == $day) ? ' selected="selected"' : '';
                                                                                
    $buffer .= qq(<option value="$i"$default>$value</option>\n);
  }

  $buffer .= qq(</select></td></tr></table>);

  return $buffer;
}

# clamav_is_quarantine_repository_empty ()
# IN: -
# OUT: true if empty
#
# Check wether the quarantine repository is empty or not.
# 
sub clamav_is_quarantine_repository_empty
{
  my @files = ();

  if (&clamav_is_mbox_format ($config{'clamav_quarantine'}))
  {
    return 1 if (! -s $config{'clamav_quarantine'});
    return 0;
  }

  opendir (DIR, $config{'clamav_quarantine'});
  @files = readdir(DIR);
  closedir (DIR);

  return (($#files - 1) <= 0);
}

# clamav_cut_string ( $ $ )
# IN: string, max length
# OUT: a cutted string
#
# Cut a string to fit in the given length, adding "[..]" atthe end.
# 
sub clamav_cut_string ( $ $ )
{   
  my ($string, $max_len) = @_;

  $string = (substr($string, 0, $max_len - 5)).' [..]'
    if (($max_len > 5) && (length ($string) >= $max_len));
                                                                                
  return $string;
}

# clamav_is_clamd_installed ()
# IN: -
# OUT: -
#
# Check if specified clamd path is ok on the system
# 
sub clamav_is_clamd_installed
{
  return (&clamav_check_systemd () || -e $config{'clamav_init_script'});
}

# clamav_activate_clamd ()
# IN: -
# OUT: -
#
# Restart the clamav daemon, waiting on second for process to be up.
# 
sub clamav_activate_clamd
{
  if (&clamav_check_systemd ())
  {
    &daemon_control_systemd ('daemon', 'start');
  }
  else
  {
    &clamav_bsd_update_state ('clamd', 'YES') if ($gconfig{'os_type'} =~ /bsd/);
    &daemon_control ($config{'clamav_init_script'}, "restart");
  }
}

# clamav_deactivate_clamd ()
# IN: -
# OUT: -
#
# Stop the clamav daemon, waiting one second for process to be down.
# 
sub clamav_deactivate_clamd
{
  if (&clamav_check_systemd ())
  {
    &daemon_control_systemd ('daemon', 'stop');
  }
  else
  {
    &daemon_control ($config{'clamav_init_script'}, "stop");
    &clamav_bsd_update_state ('clamd', 'NO') if ($gconfig{'os_type'} =~ /bsd/);
  }
}

# clamav_is_clamd_alive ()
# IN: -
# OUT: -
#
# Check wether or not clamd daemon is alive
# 
sub clamav_is_clamd_alive
{
  if (&clamav_check_systemd ())
  {
    return &daemon_control_systemd ('daemon', 'status');
  }
  else
  {
    return (&clamav_is_milter ()) ?
      &find_byname ('clamav-milter') : &find_byname ('clamd');
  }
}

# clamav_get_filtered_email_content ( $ @ )
# IN: email file name on the disk, header fields to delete
# OUT: a string with the content of the mail
#
# Search and remove given header fields from a mail
# 
sub clamav_get_filtered_email_content ( $ @)
{
  my ($file, @names) = @_;
  my $tmp_dir = "$config{'clamav_working_path'}/.clamav/$remote_user";
  my $new_file =  basename ($file);
  my $cmd = &has_command ('cat');

  if ($file =~ /\.gz$/)
  {
    $new_file =~ s/\.gz$//;
    $cmd = "$root_directory/$module_name/bin/gunzip ";
  }

  $cmd .= " $file > $tmp_dir/$new_file";
  system ($cmd);

  open (H, '<', "$tmp_dir/$new_file");
  my $m = new Mail::Internet (*H);
  close (H);
  unlink ("$tmp_dir/$new_file");

  $m->head->delete ($_) foreach (@names);
  
  return $m->as_string ();
}

# clamav_get_file_content ( $ )
# IN: file path
# OUT: fiel content
#
# Return the content of a file, wether it is uncompressed or not
#
sub clamav_get_file_content ( $ )
{
  my $file = shift;
  my $content = '';

  return if (!&is_secure ($file));
  return if (! -f $file);

  if ($file =~ /\.gz$/)
  {
    my $buf = '';
    my $gz = gzopen ($file, 'rb');
    $content .= $buf while ($gz->gzread ($buf, 4096));
    $gz->gzclose ();
  }
  else
  {
    open (H, '<', $file);
    $content = join ('', <H>);
    close (H);
  }

  return $content;
}

# clamav_get_email_header_values ( $ @ )
# IN: email file name on the disk, field to retreive value for
# OUT: a array with requested values
#
# Search and return values in a array for the requested fields,
# in the inverse order than requested
# 
sub clamav_get_email_header_values ( $ @ )
{
  my ($file, @names) = @_;
  my %header = ();
  my $item = '';
  my $i = 0;

  # If mbox format
  if (! -f $file)
  {
    my @f = split (/\n/, $file);

    LOOP1: foreach $item (@f)
    {
      chomp ($item);
      $item =~ s/^H\?\?//;
      $item =~ s/^[ ,\t]*//g;
      
      foreach my $name (@names)
      {
        if ($item =~ /^$name: /i)
        {
          $i++ if (!defined $header{$name});
          $item =~ s/^$name: //i;
          $header{$name} = $item if (!exists ($header{$name}));
	  next LOOP1;
        }
      }
    }

    return %header;
  }

  # Compressed file
  if ($file =~ /\.gz$/)
  {
    my $gzip = undef;
    
    $gzip = gzopen ($file, 'rb');
    LOOP2: while ($gzip->gzreadline ($item) && ($i <= $#names))
    {
      chomp ($item);
      $item =~ s/^H\?\?//;
      $item =~ s/^[ ,\t]*//g;
      
      foreach my $name (@names)
      {
        if ($item =~ /^$name: /i)
        {
          $i++ if (!defined $header{$name});
          $item =~ s/^$name: //i;
          $header{$name} = $item if (!exists ($header{$name}));
	  next LOOP2;
        }
      }
    }

    $gzip->gzclose ();
  }
  # Uncompressed file
  elsif (open (H, '<', $file))
  {
    LOOP3: while (defined ($item = <H>) && ($i <= $#names))
    {
      chomp ($item);
      $item =~ s/^H\?\?//;
      $item =~ s/^[ ,\t]*//g;

      foreach my $name (@names)
      {
        if ($item =~ /^$name: /i)
        {
          $i++ if (!defined $header{$name});
          $item =~ s/^$name: //i;
          $header{$name} = $item if (!exists ($header{$name}));
	  next LOOP3;
        }
      }
    }

    close (H);
  }
                                                                                
  return %header;
}

# clamav_get_log_values ( $ $ )
# IN: log file name on the disk, field to retreive value for
# OUT: a array with requested values
#
# Search and return values in a array for the requested fields,
# in the inverse order than requested
#
sub clamav_get_log_values ( $ $ )
{
  my ($file, @names) = @_;
  my %header = ();
  my $item = '';
  my $i = 0;
                                                                                
  if (open (H, '<', $file))
  {
    LOOP1: while (defined ($item = <H>) && ($i <= $#names))
    {
      foreach my $name (@names)
      {
        if ($item =~ /: $name: .*\n$/i)
        {
          $i++ if (!defined $header{$name});
          $item =~ s/^.*: $name:.*: //i;
          $header{$name} = $item;
	  next LOOP1;
        }
      }
    }
    close (H);
  }
                                                                                
  return %header;
}

# clamav_print_email ( $ )
# IN: email file on the disk
# OUT: -
#
# Display the content of the given mail file
# 
sub clamav_print_email ( $ )
{
  my $file = shift;
  my $content = '';
  my $body = '';
  my $i = 0;

  return if (!&is_secure ($file));
    
  # If mbox format
  if ($file =~ /^\d/)
  {
    my $filename = $config{'clamav_quarantine'};
    my $filehandle = new FileHandle($filename);

    my $folder_reader =
    new Mail::Mbox::MessageParser( {
      'file_name' => $filename,
      'file_handle' => $filehandle,
    } );

    # This is the main loop. It's executed once for each email
    while (!$folder_reader->end_of_file ())
    {
      my $email = $folder_reader->read_next_email ();
      if ($i == $file) {$content = $$email; last;}
      ++$i;
    }
  }
  else
  {
    # Is amavisd-new installed or amavis-ng
    $file = (&clamav_is_amavis_ng ()) ? "$file.msg" : "$file";
  
    $content = &clamav_get_file_content ("$config{'clamav_quarantine'}/$file");
    if (!$content)
    {
      printf $text{'MSG_ERROR_FILE_READ'}, "$config{'clamav_quarantine'}/$file";
      return;
    }
  }

  # Header and body are in separate files for MailScanner
  if (&clamav_is_mailscanner ())
  {
    my $dir = dirname ($file);
    my $name = basename ($file);

    $name =~ s/^./d/;
    $body = "\n" .
      &clamav_get_file_content ("$config{'clamav_quarantine'}/$dir/$name");
  }
    
  printf (qq(<textarea cols=80 rows=30>%s</textarea>\n), 
          &clamav_html_encode ("$content$body"));
}

# clamav_print_email_infos ( $ )
# IN: email file on the disk
# OUT: -
#
# Display some email information in a HTML table
# 
sub clamav_print_email_infos ( $ )
{
  my $base = shift;
  my %header = ();
  my $subject = '';
  my $from = '';
  my $to = '';

  # If amavis-ng is installed
  if (&clamav_is_amavis_ng ())
  {
    %header = &clamav_get_email_header_values (
      "$config{'clamav_quarantine'}/$base.msg",
      qw(Subject X-Quarantined-From X-Quarantined-To)
    );
    $subject = $header{'Subject'};
    $from = $header{'X-Quarantined-From'};
    $to = $header{'X-Quarantined-To'};
   }
  # If amavisd-new or clamav-milter are installed
  else
  {
    %header = &clamav_get_email_header_values (
      "$config{'clamav_quarantine'}/$base",
      qw(Subject From To)
    );
    $subject = $header{'Subject'};
    $from = $header{'From'};
    $to = $header{'To'};
  }

  $subject = &clamav_html_encode ($subject);
  $from = &clamav_html_encode ($from);
  $to = &clamav_html_encode ($to);

  print qq(
    <p><table border=0>
    <tr><td $cb><b>$text{'SUBJECT'}: </b></td><td>$subject</td><tr>
    <tr><td $cb><b>$text{'FROM'}: </b></td><td>$from</td><tr>
    <tr><td $cb><b>$text{'TO'}: </b></td><td>$to</td><tr>
    </table></p>
  );
}

# clamav_purge_quarantine
# IN: -
# OUT: OK if all is ok. If not: KO.
#
# Purge the quarantine directory
#
# If KO is returned, the global variable $clamav_error contain the errors
# strings
#
sub clamav_purge_quarantine ()
{
  my $cmd = 
    "$root_directory/$module_name/bin/purge_quarantine " .
    $config{'clamav_quarantine'};

  $clamav_error = '';

  open (H, "($cmd) 2>&1 |");
  while (<H>) {$out .= $_}
  close (H);

  $clamav_error = $out if ($out ne '');

  return ($out ne '') ? KO : OK;
}

# clamav_resend_email ( $ $ $ $ )
# IN: E-Mail file on the disk, smtp, from, to
# OUT: OK if all is ok. If not: KO.
#
# Resend a false positive email. It first test if there is an
# existing amavis-inject script on the server. if not, it use
# it is proper copy of this perl script (./bin/amavis-inject).
#
# Supported MTA are:
#
#   - rsmtp
#   - sendmail
# 
sub clamav_resend_email
{
  my ($base, $smtp, $from, $to) = @_;
  my $path = $config{'clamav_quarantine'};
  my $amavis = "$root_directory/$module_name/bin/amavis-inject ";
  my $mta = ' | '.&has_command('sendmail').' -bs '; # Use it by default
  my %header = ();
  my $out = '';
  my $args = '';
  my $cmd = '';
  my $cc = '';
  my $force = ($to ne '');
  my $content = '';
  my $tmp_dir = "$config{'clamav_working_path'}/.clamav/$remote_user";

  return KO if (!&is_secure ("$base $smtp $to $from"));
 
  # mbox format
  if ($base =~ /^\d/)
  {
    my $filename = $config{'clamav_quarantine'};
    my $filehandle = new FileHandle($filename);

    my $folder_reader =
      new Mail::Mbox::MessageParser( {
        'file_name' => $filename,
        'file_handle' => $filehandle,
      } );

    while (!$folder_reader->end_of_file ())
    {
      my $email = $folder_reader->read_next_email ();
      if ($i++ == $base) {$content = $$email; last;}
    }
  }
  else
  {
    $content = &clamav_get_filtered_email_content (
      "$path/$base".((&clamav_is_amavis_ng()) ? '.msg' : ''), 
      qw(Delivered-To 
         X-Quarantine-id X-Spam-Status X-Spam-Level 
         X-Amavis-Alert
         FCC));
  }

  open (H, '>', "$tmp_dir/email.txt"); print H $content; close (H);

  %header = &clamav_get_email_header_values ("$tmp_dir/email.txt", 
                                             qw(From To Cc));

  if ($header{'From'} =~ /\<(.*)\>/) {$header{'From'} = $1}
  if ($header{'To'} =~ /\<(.*)\>/) {$header{'To'} = $1};
  if ($header{'Cc'} =~ /\<(.*)\>/) {$header{'Cc'} = $1};
  
  # From field
  if ($from || $header{'From'})
  {
    $from = $header{'From'} if (!$from);
    $args .= " -s $from";
  }

  # To field
  if ($to || $header{'To'})
  {
    $to = $header{'To'} if (!$to);
  }

  # Cc field
  # Only get Cc content if recipient was not forced by user
  if (!$force && $header{'Cc'})
  {
    $to .= ','.$header{'Cc'};
  }

  if ($to)
  {
    $to =~ s/(\s|\<|\>|\,$)//g;
    foreach (split (/\,/, $to))
    {
      $args .= " -r $_";
    }
  }

  if ($smtp)
  {
    # Test is given SMTP host or IP is alive
    if (!&smtphost_is_alive ($smtp))
    {
      return NET_PING_KO;
    }

    $args .= " --smtp $smtp";
    $mta = ''; # amavis-inject will send it itself
  }
  
  # If rsmtp is found, use it instead of sendmail
  if (defined (my $tmp = &has_command ('rsmtp')))
  {
    $mta = " | $tmp ";
  }

  $cmd = "$amavis $args $tmp_dir/email.txt $mta";

  open (H, "($cmd) 2>&1 |");
  while (<H>) {$out .= $_ if (! /^\d+\s/)}
  close (H);

  $clamav_error = $out if ($out ne '');

  unlink ("$tmp_dir/email.txt");

  return ($out ne '') ? KO : OK;
}

# smtphost_is_alive ( $ )
# IN: hostname or IP to test
# OUT: 1 if the SMTP host is alive
#
# Check if a given SMTP IP or host is alive and listen on a given port (25 
# by default)
#
sub smtphost_is_alive ()
{
  my $host = shift;
  my $port = 25;
  my $ret = 1;
  my $s;

  if ($host =~ /(.*)\:(.*)/)
  {
    ($host, $port) = ($1, $2);
  }

  $s = new IO::Socket::INET (
    Proto => "tcp",
    PeerAddr => $host,
    PeerPort => $port
  ) || ($ret = 0);
  close ($s) if ($s);

  return $ret;
}

# is_secure ( $ )
# IN: string to check
# OUT: 1 if the string passed is secure
#
# Check is a string to be passed on command line is secure for our usage or not
# 
sub is_secure
{
  my $n = shift;

  return ($n =~ /^[A-Z0-9 \-_\.\/\+\&\%\@:]*$/i && $n !~ /\.\./);
}

# clamav_learn_notaspam ( $ )
# IN: name of the email file on the disk
# OUT: OK if all is ok. If not: KO.
#
# Learn spam detection system that this E-Mail is not a spam
# 
sub clamav_learn_notaspam
{
  my $base = shift;
  my $file = $config{'clamav_quarantine'}."/$base";

  return KO if (!&is_secure ($base));
  
  # If amavis-ng is installed
  $file .= '.msg ' if (&clamav_is_amavis_ng ());

  $content = &clamav_get_file_content ($file);
  $sa = Mail::SpamAssassin->new ({username => $config{'clamav_spam_user'}});
  $sa->init_learner ();

  $mail = $sa->parse ($content, 1);
  $sa->learn ($mail);
  $sa->rebuild_learner_caches ();
  $sa->finish_learner ();
  $mail->finish ();

  return OK;
}

# clamav_remove_email ( $ )
# IN: base name of the email file on the disk
# OUT: OK if all is ok. If not: KO.
#
# Delete a email and its associated log file on the quarantine repository.
# 
sub clamav_remove_email
{
  my $base = shift;
  my $res = -1;

  return KO if (!&is_secure ($base));
  
  # mbox format
  if ($base =~ /^\d/)
  {
    my $filename = $config{'clamav_quarantine'};
    my $filehandle = new FileHandle($filename);

    my $folder_reader =
      new Mail::Mbox::MessageParser( {
        'file_name' => $filename,
        'file_handle' => $filehandle,
      } );

    $tmppath = "$config{'clamav_working_path'}/.clamav/$remote_user/".time();
    open (H, '>', $tmppath);
    my $i = 0;
    while (!$folder_reader->end_of_file ())
    {
      my $email = $folder_reader->read_next_email ();
      print H "$$email" if ($i++ != $base);
    }
    close (H);

    move ($tmppath, $config{'clamav_quarantine'});

    return OK;
  }

  # If amavis-ng is installed
  if (&clamav_is_amavis_ng ())
  {
    $res = 
      system (&has_command('rm').' -f '.
              quotemeta($config{'clamav_quarantine'}).'/'.
              quotemeta($base).'.*');
  }
  # If mailscanner 
  elsif (&clamav_is_mailscanner ())
  {
    $res = 
      system (&has_command('rm'), '-rf',
              $config{'clamav_quarantine'}.'/'.dirname($base));
  }
  # If amavisd-new, qmailscanner or clamav-milter is installed
  else
  {
    $res = 
      system (&has_command('rm'), '-f',
              $config{'clamav_quarantine'}."/$base");
  }

  return ($res != 0) ? KO : OK;
}

# clamav_print_log ( $ $ )
# IN: file to display, number of lines to display
# OUT: -
#
# Display the content of the given log file
#
sub clamav_print_log
{
  my ($file, $lines) = @_;
  my @content = ();
  my $tail = &has_command ('tail');

  return if (!&is_secure ($file) || !&is_secure ($lines));
  
  open (H, '<', $file);
  if (!$lines)
    {@content = <H>}
  else
    {@content = `$tail -n $lines $file`}
  close (H);
                                                                                
  printf (qq(<textarea cols=80 rows=30>%s</textarea>\n), 
          &clamav_html_encode ("@content"));
}

# clamav_quarantine_print_log ( $ )
# IN: email log file on the disk
# OUT: -
#
# Display the content of the given mail log file
#
sub clamav_quarantine_print_log ( $ )
{
  my $file = shift;
  my $content = '';

  return if (!&is_secure ($file) || $file =~ /\//);
    
  $content = 
    &clamav_get_file_content ("$config{'clamav_quarantine'}/$file.log");
                                                                                
  printf (qq(<textarea cols=80 rows=30>%s</textarea>\n), 
          &clamav_html_encode ($content));
}

# clamav_print_quarantine_table_mailscanner ( $ $ $ $ $ $ $ $ $ $ $ )
# IN: search type ('virus', 'spam')
#     current page
#     virus name to search for
#     from
#     to
#     day1
#     month1
#     year1
#     day2
#     month2
#     year2
# OUT: -
#
# -- used if mailscanner has been found --
# 
# Display a HTML table containing on line per email found in the quarantine
# repository
# 
sub clamav_print_quarantine_table_mailscanner ( $ $ $ $ $ $ $ $ $ $ $)
{
  my ($search_type, $current, $virus_name, $mail_from, $mail_to,
      $day1, $month1, $year1,
      $day2, $month2, $year2) = @_;
  my $date1 = '';
  my $date2 = '';
  my $i = 0;
  my $count = 0;
  my @files = ();
  my @arows = ();
  my $cyear = &clamav_get_current_year ();
  my $is_spam = 0;
  my %hrow = ();

  $current = int ($current);

  $date1 = &clamav_format_date ($day1, $month1, ($year1) ? $year1 : $cyear);
  $date2 = &clamav_format_date ($day2, $month2, ($year2) ? $year2 : $cyear);

  $virus_name =~ s/ //g;
  $mail_from =~ s/ //g;
  $mail_to =~ s/ //g;

  opendir (DIR, $config{'clamav_quarantine'});
  while (my $dir = readdir (DIR))
  {
    next if ($dir =~ /^\./);
    
    opendir (DIR1, "$config{'clamav_quarantine'}/$dir/");
    while (my $dir1 = readdir (DIR1))
    {
      next if ($dir1 =~ /^\./) || ($dir1 eq 'spam');

      $is_spam = (-f "$config{'clamav_quarantine'}/$dir/spam/df$dir1");

      opendir (DIR2, "$config{'clamav_quarantine'}/$dir/$dir1/");
      while (my $file = readdir (DIR2))
      {
        next if ($file =~ /^\./);
        next if (($search_type eq 'virus' || $search_type eq 'spam') && 
	  $file !~ /^q/ && $file ne 'message');
	
	$file .= '-spam' if $is_spam;
        push @files, "$dir/$dir1/$file";
      };
      closedir (DIR2);
    };
    closedir (DIR1);
  }

  # Browse result and push it in a array to manage pagination
  $count = 0;
  for ($i = 0; $i < $#files + 1; $i++)
  {
    my $msg = $files[$i];
    my $quarantine_path = $config{'clamav_quarantine'};

    # Virus type
    if ($search_type eq 'virus' && $msg !~ /-spam$/)
    {
      my %header = &clamav_get_email_header_values (
          "$quarantine_path/$msg",
          qw(Subject From To)
        );

      next if (!&clamav_quarantine_add_row ($header{'Subject'}, '', 
        $msg, '...', '...', $mail_from, $header{'From'}, $mail_to, 
        $header{'To'}, "$quarantine_path/$msg", $date1, $date2, \@arows));

        $count++;
    }
    # Spam type
    elsif ($search_type eq 'spam' && $msg =~ /-spam$/)
    {
      $msg =~ s/-spam$//;
      my %header = &clamav_get_email_header_values (
          "$quarantine_path/$msg",
          qw(Subject From To)
        );

      next if (!&clamav_quarantine_add_row ($header{'Subject'}, '',
        $msg, '', '', $mail_from, $header{'From'}, $mail_to,
        $header{'To'}, "$quarantine_path/$msg", $date1, $date2, \@arows));
        $count++;
    }
  }
  
  # Return if no result
  if ($count <= 0)
  { 
    print qq(<p><b>$text{'NO_RESULT_QUARANTINE'}</b></p>);
    return;
  }

  @arows = sort clamav_sort_by_date_quarantine_table (@arows);

  &clamav_print_quarantine_table_display ($current, $search_type, 
    \%hrow, \@arows);

  return $count;
}

# clamav_get_current_year ()
# IN: -
# OUT: -
#
# Return the current yeaR
# 
sub clamav_get_current_year ()
{
  return ((localtime (time ()))[5]) + 1900;
}

# clamav_print_quarantine_table_milter ( $ $ $ $ $ $ $ $ $ $ $ )
# IN: search type ('virus', 'spam')
#     current page
#     virus name to search for
#     from
#     to
#     day1
#     month1
#     year1
#     day2
#     month2
#     year2
# OUT: -
#
# -- used if clamav-milter has been found --
# 
# Display a HTML table containing on line per email found in the quarantine
# repository
# 
sub clamav_print_quarantine_table_milter ( $ $ $ $ $ $ $ $ $ $ $ )
{
  my ($search_type, $current, $virus_name, $mail_from, $mail_to,
      $day1, $month1, $year1,
      $day2, $month2, $year2) = @_;
  my @files = ();
  my @arows = ();
  my %hrow = ();
  my $i = 0;
  my $count = 0;
  my $date1 = '';
  my $date2 = '';
  my $cyear = &clamav_get_current_year ();

  $current = int ($current);

  $date1 = &clamav_format_date ($day1, $month1, ($year1) ? $year1 : $cyear);
  $date2 = &clamav_format_date ($day2, $month2, ($year2) ? $year2 : $cyear);

  $virus_name =~ s/ //g;
  $mail_from =~ s/ //g;
  $mail_to =~ s/ //g;

  opendir (DIR, $config{'clamav_quarantine'});
  while (my $dir = readdir (DIR))
  {
    next if ($dir =~ /^\./);
    
    opendir (DIR1, "$config{'clamav_quarantine'}/$dir/");
    while (my $file = readdir (DIR1))
    {
      next if ($file =~ /^\./);
      push @files, "$dir/$file";
    };
    closedir (DIR1);
  }

  # Browse result and push it in a array to manage pagination
  $count = 0;
  for ($i = 0; $i < $#files + 1; $i++)
  {
    next if ($files[$i] =~ /^\./) || ($files[$i] =~ /^spam/);
      
    my $msg = $files[$i];
    my $quarantine_path = $config{'clamav_quarantine'};
    my %header = &clamav_get_email_header_values (
        "$quarantine_path/$msg",
        qw(Subject From To)
      );
    my $virus = '';
    my $url_virus = '';
    
    $msg =~ /msg\.[\w]+\.(.*)$/;
    $virus = $1;
    $url_virus = &urlize ($virus);

    next if (!&clamav_quarantine_add_row ($header{'Subject'}, $url_virus, 
      $msg, $virus_name, $virus, $mail_from, $header{'From'}, $mail_to, 
      $header{'To'}, "$quarantine_path/$msg", $date1, $date2, \@arows));

      $count++;
  }
  
  # Return if no result
  if ($count <= 0)
  { 
    print qq(<p><b>$text{'NO_RESULT_QUARANTINE'}</b></p>);
    return;
  }

  @arows = sort clamav_sort_by_date_quarantine_table (@arows);

  &clamav_print_quarantine_table_display ($current, $search_type, 
    \%hrow, \@arows);

  return $count;
}

# clamav_print_quarantine_table_amavis_ng ( $ $ $ $ $ $ $ $ $ $ $ )
# IN: search type ('virus', 'spam')
#     current page
#     virus name to search for
#     from
#     to
#     day1
#     month1
#     year1
#     day2
#     month2
#     year2
# OUT: -
#
# -- used if amavis-ng has been found --
# 
# Display a HTML table containing on line per email found in the quarantine
# repository
# 
sub clamav_print_quarantine_table_amavis_ng ( $ $ $ $ $ $ $ $ $ $ $ )
{
  my ($search_type, $current, $virus_name, $mail_from, $mail_to,
      $day1, $month1, $year1,
      $day2, $month2, $year2) = @_;
  my $STRING_MAX_LEN = 30;
  my $date1 = '';
  my $date2 = '';
  my $i = 0;
  my $page_count = 0;
  my $count = 0;
  my @files = ();
  my @arows = ();
  my $cyear = &clamav_get_current_year ();

  $current = int ($current);

  $date1 = &clamav_format_date ($day1, $month1, ($year1) ? $year1 : $cyear);
  $date2 = &clamav_format_date ($day2, $month2, ($year2) ? $year2 : $cyear);

  $virus_name =~ s/ //g;
  $mail_from =~ s/ //g;
  $mail_to =~ s/ //g;

  opendir (DIR, $config{'clamav_quarantine'});
  @files = readdir (DIR);
  closedir (DIR);

  # Browse result and push it in a array to manage pagination
  $count = 0;
  for ($i = 0; $i < $#files + 1; $i += 2)
  {
    next if ($files[$i] eq '.');
      
    my $log = $files[$i];
    my $msg = $files[$i + 1];
    my $quarantine_path = $config{'clamav_quarantine'};
    my $base = $log; $base =~ s/\..*$//g;
    my %header = &clamav_get_email_header_values (
        "$quarantine_path/$base.msg",
        qw(Subject X-Quarantined-From X-Quarantined-To)
      );
    my $subject = $header{'Subject'};
    my $from = $header{'X-Quarantined-From'};
    my $to = $header{'X-Quarantined-To'};
    my %header = &clamav_get_log_values (
        "$quarantine_path/$base.log",
        qw(AMAVIS::AV::CLAMD)
      );
    my $virus = $header{'AMAVIS::AV::CLAMD'};
    my $url_virus = &urlize ($virus);
    my $fdate = '';

    next if (!&clamav_quarantine_add_row ($subject, $url_virus, 
      $base, $virus_name, $virus, $mail_from, $from, $mail_to, $to, 
      "$quarantine_path/$base.msg", $date1, $date2, \@arows));

      $count++;
  }
  
  # Return if no result
  if ($count <= 0)
  { 
    print qq(<p><b>$text{'NO_RESULT_QUARANTINE'}</b></p>);
    return;
  }

  print qq(
    <table>
    <tr $tb>
    <td><b>$text{'DATE'}</b></td>
    <td><b>$text{'SUBJECT'}</b></td>
    <td><b>$text{'VIRUS'}</b></td>
    <td><b>$text{'FROM'}</b></td><td><b>$text{'TO'}</b></td>);
    
  if (&clamav_get_acl ('quarantine_resend') +
    &clamav_get_acl ('quarantine_delete') != 0)
    {print qq(<td colspan=2><b>$text{'ACTION'}</b></td>)}
    
  print qq(</tr>);

  # Write javascript function to select/unselect all items
  &clamav_print_javascript_check_uncheck_all (0, 'quarantine_file');

  # Display search result
  for ($i = ceil ($current * MAX_PAGE_ITEMS); 
    $i < $#arows + 1 && $page_count++ < MAX_PAGE_ITEMS; $i++)
  {
    my %hrow = %{$arows[$i]};

    my $subjectc = &clamav_cut_string ($hrow{'subject'}, $STRING_MAX_LEN);
    my $fromc = &html_escape (&clamav_cut_string ($hrow{'from'}, 
      $STRING_MAX_LEN));
    my $toc = &html_escape (&clamav_cut_string ($hrow{'to'}, $STRING_MAX_LEN));
    my $virusc = &clamav_cut_string ($hrow{'virus'}, $STRING_MAX_LEN);
     
    print qq(
      <tr>
      <td $cb title="$text{'DATE'}: $hrow{'date'} | $text{'FROM'}: $hrow{'from'} | $text{'TO'}: $hrow{'to'} | $text{'VIRUS'}: $hrow{'virus'} | $text{'SUBJECT'}: $hrow{'subject'}"><i><small><a href="quarantine_viewmail.cgi?base=);
    print &urlize ($hrow{'base'});
    print qq(">$hrow{'date'}</a></small></i></td>
      <td $cb>$subjectc</td>
      <td $cb><b><a href="/$module_name/vdb_search_main.cgi?search=on&virus=$hrow{'url_virus'}" title="$text{'VIRUS'}: $hrow{'virus'}">$virusc</a></b></td>
      <td $cb title="$text{'FROM'}: $hrow{'from'}">$fromc</td>
      <td $cb title="$text{'TO'}: $hrow{'to'}">$toc</td>
      <td $cb><a href="quarantine_viewlog.cgi?base=);
    print &urlize ($hrow{'base'});
    print qq(">$text{'VIEWLOG'}</a></td>);

    if (&clamav_get_acl ('quarantine_resend') +
      &clamav_get_acl ('quarantine_delete') != 0)
    {
      if (&clamav_get_acl ('quarantine_resend') == 1)
      {
        print qq(<td $cb><a href="quarantine_resend.cgi?newto=1&quarantine_file0=);
	print &urlize ($hrow{'base'});
	print qq(">$text{'RESEND'}</a></td>);
      }
      else
      {
        print qq(<td></td>);
      }
	    
      if (&clamav_get_acl ('quarantine_delete') == 1)
      {
        print qq(<td $cb><input type="checkbox" name="quarantine_file$i" value="$hrow{'base'}"></td>);
      }
      else
      {
        print qq(<td></td>);
      }
    }
	
    print qq(</tr>);
  }

  print qq(</table>);

  if (&clamav_get_acl ('quarantine_delete') == 1)
  {
    print qq(
      <p><input id="checkuncheck" type="checkbox" onClick="check_uncheck_all (this.checked)"> <label for="checkuncheck">$text{'CHECK_UNCHECK_ALL'}</label></p>
      <p><input type="submit" name="delete" value="$text{'DELETE_SELECTED'}"> <input type="submit" name="delete_all" value="$text{'PURGE_QUARANTINE_NOW'}"></p>);
  }

  return $count;
}

# get_match_files_in_dirs ( $ $ $ )
# IN: Directory to search in
#     ref on a array for push files into
#     condition to match
# OUT: -
#
# Put files matching filter in a directory and its subdirectories in a array
#
sub get_match_files_in_dirs ()
{
  my ($dir, $files, $filter) = @_;
  local *DIR;

  opendir (DIR, $dir);
  while (my $f = readdir (DIR))
  {
    next if ($f =~ /^\./);
    if (-d "$dir/$f") {&get_all_files_in_dirs ("$dir/$f", $files, $filter)}
      else {push @$files, "$dir/$f" if ("$dir/$f" =~ /$filter/)}
  }
  closedir (DIR);
}

# get_all_files_in_dirs ( $ $ )
# IN: Directory to search in
#     ref on a array for push files into
# OUT: -
#
# Put all found files in a directory and its subdirectories in a array
#
sub get_all_files_in_dirs ()
{
  my ($dir, $files) = @_;
  local *DIR;

  opendir (DIR, $dir);
  while (my $f = readdir (DIR))
  {
    next if ($f =~ /^\./);
    if (-d "$dir/$f") {&get_all_files_in_dirs ("$dir/$f", $files)}
      else {push @$files, "$dir/$f"}
  }
  closedir (DIR);
}

# clamav_print_quarantine_table_amavisd_new ( $ $ $ $ $ $ $ $ $ $ $ $)
# IN: search type ('virus', 'spam')
#     current page
#     virus name to search for
#     from
#     to
#     day1
#     month1
#     year1
#     day2
#     month2
#     year2
# OUT: -
# 
# -- used if amavisd-new has been found --
#
# Display a HTML table containing on line per email found in the quarantine
# repository
# 
sub clamav_print_quarantine_table_amavisd_new ( $ $ $ $ $ $ $ $ $ $ $ )
{
  my ($search_type, $current, $virus_name, $mail_from, $mail_to,
      $day1, $month1, $year1,
      $day2, $month2, $year2) = @_;
  my $date1 = '';
  my $date2 = '';
  my $i = 0;
  my $count = 0;
  my $end = 0;
  my @files = ();
  my @arows = ();
  my %hrow = ();
  my $cyear = &clamav_get_current_year ();
  my $mbox = 0;

  $current = int ($current);

  $date1 = &clamav_format_date ($day1, $month1, ($year1) ? $year1 : $cyear);
  $date2 = &clamav_format_date ($day2, $month2, ($year2) ? $year2 : $cyear);

  $virus_name =~ s/ //g;
  $mail_from =~ s/ //g;
  $mail_to =~ s/ //g;

  # If mbox format
  if (&clamav_is_mbox_format ($config{'clamav_quarantine'}))
  {
    my $filename = $config{'clamav_quarantine'};
    my $filehandle = new FileHandle($filename);

    $mbox = 1;

    my $folder_reader =
      new Mail::Mbox::MessageParser( {
        'file_name' => $filename,
        'file_handle' => $filehandle,
      } );

    # This is the main loop. It's executed once for each email
    while (!$folder_reader->end_of_file ())
    {
      my $email = $folder_reader->read_next_email ();
      $files[$i++] = $$email;
    }
  }
  else
  {
    &get_all_files_in_dirs ($config{'clamav_quarantine'}, \@files);
  }

  # Browse result and push it in a array to manage pagination
  my $quarantine_path = $config{'clamav_quarantine'};
  my $p = quotemeta ($quarantine_path);
  $count = 0;
  $end = $#files + 1;
  for ($i = 0; $i < $end; $i++)
  {
    my $msg = '';
    my $mail = '';
    my $file = '';

    if (!$mbox)
    {
      $files[$i] =~ s/^$p//;
      $file = basename ($files[$i]);
      $msg = $files[$i];
      $mail = "$quarantine_path/$msg";
    }
    else
    {
      my $msg = $i;
      $mail = $files[$i];
      my %header = &clamav_get_email_header_values (
          $files[$i], qw(Delivered-To));
      $file = $header{'Delivered-To'};
    }

    # Virus type
    if ($search_type eq 'virus' && $file =~ /^virus/)
    {
      my %header = &clamav_get_email_header_values (
          $mail,
          qw(Date Subject From To X-AMaViS-Alert)
        );
      my $virus = $header{'X-AMaViS-Alert'};
      ($virus) = (split (/:/, $virus))[1];
      $virus =~ s/[ ,\n,\r]//g;

      next if (!&clamav_quarantine_add_row ($header{'Subject'}, 
        &urlize ($virus), $msg, $virus_name, $virus, $mail_from, 
	$header{'From'}, $mail_to, $header{'To'}, 
        ($mbox) ? $header{'Date'} : $mail, $date1, $date2, \@arows));

      $count++;
    }
    # Spam type
    elsif ($search_type eq 'spam' && $file =~ /^spam/)
    {
      my %header = &clamav_get_email_header_values (
          $mail,
          qw(Date Subject From To X-Spam-Level)
        );
      my $level = ": $header{'X-Spam-Level'}";
      ($level) = (split (/:/, $level))[1];
      $level =~ s/[ ,\n,\r]//g;

      next if (!&clamav_quarantine_add_row ($header{'Subject'}, '', 
        $msg, '', $level, $mail_from, $header{'From'}, $mail_to, 
	$header{'To'}, ($mbox) ? $header{'Date'} : $mail,
        $date1, $date2, \@arows));

      $count++;
    }
    # Bad header type
    elsif ($search_type eq 'badh' && $file =~ /^badh/)
    {
      my %header = &clamav_get_email_header_values (
          $mail,
          qw(Date Subject From To X-AMaViS-Alert)
        );
      my $description = $header{'X-AMaViS-Alert'};

      next if (!&clamav_quarantine_add_row ($header{'Subject'}, 
        '', $msg, '', $description, $mail_from, 
	$header{'From'}, $mail_to, $header{'To'}, 
        ($mbox) ? $header{'Date'} : $mail, $date1, $date2, \@arows));

      $count++;
    }
    # Banned type
    elsif ($search_type eq 'banned' && $file =~ /^banned/)
    {
      my %header = &clamav_get_email_header_values (
          $mail,
          qw(Date Subject From To X-AMaViS-Alert)
        );
      my $description = $header{'X-AMaViS-Alert'};

      next if (!&clamav_quarantine_add_row ($header{'Subject'}, 
        '', $msg, '', $description, $mail_from, 
	$header{'From'}, $mail_to, $header{'To'},
        ($mbox) ? $header{'Date'} : $mail, $date1, $date2, \@arows));

      $count++;
    }
  }

  # Return if no result
  if ($count <= 0)
  { 
    print qq(<p><b>$text{'NO_RESULT_QUARANTINE'}</b></p>);
    return;
  }

  @arows = sort clamav_sort_by_date_quarantine_table (@arows);

  &clamav_print_quarantine_table_display ($current, $search_type, 
    \%hrow, \@arows);

  return $count;
}

# clamav_print_quarantine_table_qmailscanner ( $ $ $ $ $ $ $ $ $ $ $ $)
# IN: search type ('virus', 'spam')
#     current page
#     virus name to search for
#     from
#     to
#     day1
#     month1
#     year1
#     day2
#     month2
#     year2
# OUT: -
# 
# -- used if qmailscanner has been found --
#
# Display a HTML table containing on line per email found in the quarantine
# repository
# 
sub clamav_print_quarantine_table_qmailscanner ( $ $ $ $ $ $ $ $ $ $ $ )
{
  my ($search_type, $current, $virus_name, $mail_from, $mail_to,
      $day1, $month1, $year1,
      $day2, $month2, $year2) = @_;
  my $date1 = '';
  my $date2 = '';
  my $i = 0;
  my $count = 0;
  my @files = ();
  my @arows = ();
  my %hrow = ();
  my $cyear = &clamav_get_current_year ();

  $current = int ($current);

  $date1 = &clamav_format_date ($day1, $month1, ($year1) ? $year1 : $cyear);
  $date2 = &clamav_format_date ($day2, $month2, ($year2) ? $year2 : $cyear);

  $virus_name =~ s/ //g;
  $mail_from =~ s/ //g;
  $mail_to =~ s/ //g;

  &get_match_files_in_dirs ($config{'clamav_quarantine'}, \@files, "\/new\/");

  # Browse result and push it in a array to manage pagination
  $count = 0;
  for ($i = 0; $i < $#files + 1; $i++)
  {
    my $msg = $files[$i];
    my $quarantine_path = $config{'clamav_quarantine'};
    my %header = &clamav_get_email_header_values (
        "$msg", qw(Subject From To Quarantine-Description X-Spam-Level)
    );

    # Virus type
    if ($search_type eq 'virus' && $header{'X-Spam-Level'} eq '')
    {
      my $virus = $header{'Quarantine-Description'};
      $virus =~ s/[ \n\r]//g;

      next if (!&clamav_quarantine_add_row ($header{'Subject'}, 
        &urlize ($virus), $msg, $virus_name, $virus, $mail_from, 
	$header{'From'}, $mail_to, $header{'To'}, $msg, 
	$date1, $date2, \@arows));

      $count++;
    }
    # Spam type
    elsif ($search_type eq 'spam' && $header{'X-Spam-Level'} ne '')
    {
      my $level = ": $header{'X-Spam-Level'}";
      ($level) = (split (/:/, $level))[1];
      $level =~ s/[ \n\r]//g;

      next if (!&clamav_quarantine_add_row ($header{'Subject'}, '', 
        $msg, '', $level, $mail_from, $header{'From'}, $mail_to, 
	$header{'To'}, $msg, $date1, $date2, \@arows));

      $count++;
    }
  }

  # Return if no result
  if ($count <= 0)
  { 
    print qq(<p><b>$text{'NO_RESULT_QUARANTINE'}</b></p>);
    return;
  }

  @arows = sort clamav_sort_by_date_quarantine_table (@arows);

  &clamav_print_quarantine_table_display ($current, $search_type, 
    \%hrow, \@arows);

  return $count;
}


# clamav_quarantine_add_row ( $ $ $ $ $ $ $ $ $ $ $ $ \@)
# IN: subject
#     url for virus search
#     basename of the file
#     virus name to search for
#     virus of the current E-Mail
#     from to search for
#     from of the current E-Mail
#     to to search for
#     to of the current E-Mail
#     location of the E-Mail file in quarantine
#     first date of the search period
#     second date of the search period
#     array reference to stock the new hash row
# OUT: 0 if bad, 1 if ok
#
# apply filters and add hash of the row items for futur display
#
sub clamav_quarantine_add_row ( $ $ $ $ $ $ $ $ $ $ $ $ \@ )
{
  my ($fdate, $fdate_comp) = ('', '');
  my ($subject, $url_virus, $base, $virus_name, $virus, $mail_from, $from, 
    $mail_to, $to, $file, $date1, $date2, $a) = @_;
  my $mbox = (! -f $file);
  
  # Applying filters
  return 0 if (
    ($virus_name && $virus !~ /$virus_name/i) ||
    ($mail_from && $from !~ /$mail_from/i) ||
    ($mail_to && $to !~ /$mail_to/i)
  );
    
  if ($mbox)
  {
    $fdate = &UnixDate ($file, "%Y-%m-%d %H:%M");
  }
  else
  {
    $fdate = strftime ('%Y-%m-%d %H:%M', localtime ((stat ($file))[9]));
  }

  $fdate_comp = substr ($fdate, 0, 10);

  return 0 if (
    ($date1 && (&Date_Cmp ($fdate_comp, $date1) < 0 || 
      ($date2 && &Date_Cmp ($fdate_comp, $date2) > 0))) ||
    ($date2 && &Date_Cmp ($fdate_comp, $date2) > 0)
  );

  push (@$a, {
    'date' => $fdate,
    'subject' => $subject,
    'from' => $from,
    'to' => $to,
    'virus' => $virus,
    'url_virus' => $url_virus,
    'base' => $base
  });

  return 1;
}

# clamav_sort_by_date_quarantine_table ( $ $ )
# IN: First item
#     Second item
# OUT: Comparison result (cmp)
#
# This function sort the result by date
# 
sub clamav_sort_by_date_quarantine_table ( $ $ )
{
  $_[0]->{'date'} cmp $_[1]->{'date'};
}

# clamav_download ( $ )
# IN: file to download
# OUT: -
#
# Send a file to download to the browser
#
sub clamav_download ()
{
  my $file = shift;
  my $size = (stat ($file))[7];

  print "Content-Type: text/csv\n";
  print "Content-Length: $size\n";
  print "Expires: Sun, 01 Jan 1970 12:00:00\n";

  if ($ENV{'HTTP_USER_AGENT'} =~ 'MSIE')
  {
    print "Content-Disposition: inline; filename=\"quarantine-export.csv\"\n";
    print "Cache-Control: must-revalidate, post-check=0, pre-check=0\n";
    print "pragma: public\n";
  }
  else
  {
    print 
      "Content-Disposition: attachment; filename=\"quarantine-export.csv\"\n";
    print "Pragma: no-cache\n";
  }
  print "\n";

  open (F, '<', $file);
  while (<F>) {print;}
  close (F);

  exit;
}

# clamav_print_quarantine_table_display ( $ $ \% \@ )
# IN: current page
#     search type ('virus', 'spam')
#     hash ref on rows items
#     array ref of rows
# OUT: -
#
# This function is shared by all functions that display quarantine
# search results
# 
sub clamav_print_quarantine_table_display ( $ $ \% \@ )
{
  my ($current, $search_type, $a, $b) = @_;
  my %hrow = %$a;
  my @arows = @$b;
  my $page_count = 0;
  my $i = 0;
  my $STRING_MAX_LEN = 30;

  if (&clamav_get_acl ('quarantine_delete') == 1 ||
    &clamav_get_acl ('quarantine_resend') == 1)
  {
    # Write javascript function to select/unselect all items
    &clamav_print_javascript_check_uncheck_all (0, 'quarantine_file');

    if (&clamav_get_acl ('quarantine_export') == 1)
    {
      print qq(<input type="submit" name="export" 
                      value="$text{'EXPORT'}">);
    }

     print qq(
       <p>
       <input id="checkuncheck" type="checkbox" 
              onClick="check_uncheck_all (this.checked)"> 
       <label for="checkuncheck">$text{'CHECK_UNCHECK_ALL'}</label>
       </p>
     );
	 
    if (&clamav_get_acl ('quarantine_delete') == 1)
    {
      print qq(
        <p><input type="submit" name="delete" 
	          value="$text{'DELETE_SELECTED'}">);
    }
    
    if (&clamav_get_acl ('quarantine_resend') == 1)
    {
      print qq(<input type="submit" name="resend" 
                      value="$text{'RESEND_SELECTED'}">);
    }

    print qq(</p>);
  }

  print qq(
    <table border=1>
    <tr $tb>
    <td><b>$text{'DATE'}</b></td><td><b>$text{'SUBJECT'}</b></td>);
  # Spam
  if ($search_type eq 'spam') 
  {
    print "<td><b>$text{'SPAM_LEVEL'}</b></td>" 
      if (!&clamav_is_mailscanner ());
  }
  # Bad header
  elsif ($search_type eq 'badh' || $search_type eq 'banned')
  {
    print "<td><b>$text{'DESCRIPTION'}</b></td>";
  }
  # Virus
  else 
  {
    print "<td><b>$text{'VIRUS'}</b></td>";
  }
  print qq(<td><b>$text{'FROM'}</b></td><td><b>$text{'TO'}</b></td>);

  if (&clamav_get_acl ('quarantine_resend') == 1 ||
    &clamav_get_acl ('quarantine_delete') == 1)
  {
    print qq(<td><b>$text{'ACTION'}</b></td>);
  }
    
  print qq(</tr>);

  my $dir = "$config{'clamav_working_path'}/.clamav/$remote_user";
  open (F, '>', "$dir/quarantine-export.csv");
  my $export_line = "type;date;hour;subject;description;level;virus;from;to\n";
  print F $export_line;

  # Display search result
  for ($i = ceil ($current * MAX_PAGE_ITEMS); 
    $i < $#arows + 1 && $page_count++ < MAX_PAGE_ITEMS; $i++)
  {
    $export_line = '"'.$search_type.'"';
    my %hrow = %{$arows[$i]};

    my $subject = &clamav_html_encode_quotes ($hrow{'subject'}); 
    my $from = &clamav_html_encode_quotes ($hrow{'from'}); 
    my $to = &clamav_html_encode_quotes ($hrow{'to'}); 
    my $virus = &clamav_html_encode_quotes ($hrow{'virus'}); 

    my $subjectcsv = &clamav_escape_quotes ($hrow{'subject'}); 
    my $fromcsv = &clamav_escape_quotes ($hrow{'from'}); 
    my $tocsv = &clamav_escape_quotes ($hrow{'to'}); 
    my $viruscsv = &clamav_escape_quotes ($hrow{'virus'}); 

    my $subjectc = &clamav_cut_string ($hrow{'subject'}, $STRING_MAX_LEN);
    my $fromc = &clamav_cut_string ($hrow{'from'}, $STRING_MAX_LEN);
    my $toc = &clamav_cut_string ($hrow{'to'}, $STRING_MAX_LEN);
    my $virusc = ($search_type ne 'badh' && $search_type ne 'banned') ?
      &clamav_cut_string ($hrow{'virus'}, $STRING_MAX_LEN) : $hrow{'virus'};

    $subjectc = &clamav_html_encode ($subjectc); 
    $fromc = &clamav_html_encode ($fromc); 
    $toc = &clamav_html_encode ($toc); 
    if ($search_type eq 'spam') {$virusc = length ($virusc)}
      else {$virusc = &clamav_html_encode ($virusc)}

    print qq(
        <tr>
	<td $cb title="$text{'DATE'}: $hrow{'date'} | $text{'FROM'}: $from | $text{'TO'}: $to | );
	# Spam
	if ($search_type eq 'spam')
	{
          print $text{'SPAM_LEVEL'} if (!&clamav_is_mailscanner ());
	}
	# Bad header
	elsif ($search_type eq 'badh' || $search_type eq 'banned')
	{
          print $text{'DESCRIPTION'};
	}
	# Virus
	else
	{
          print $text{'VIRUS'};
	}
	my ($d, $h) = split (/ /, $hrow{'date'});
	$export_line .= ';"'.$d.'";"'.$h.'"';
	print qq(: $virus | $text{'SUBJECT'}: ${subject}"><i><small><a href="quarantine_viewmail.cgi?base=);
	print &urlize ($hrow{'base'});
	print qq(" target="_BLANK">$hrow{'date'}</small></i></td><td $cb>$subjectc</a></td>);
	$export_line .= ';"'.$subjectcsv.'"';
      # Spam
      if ($search_type eq 'spam')
      {
        print qq(<td $cb title="$text{'SPAM_LEVEL'}: $virus"><b>$virusc</b></td>) if (!&clamav_is_mailscanner ());
	$export_line .= ';"";"'.$viruscsv.'";""';
      }
      # Bad header
      elsif ($search_type eq 'badh' || $search_type eq 'banned')
      {
        print qq(<td $cb>$virusc</td>);
	$export_line .= ';"'.$viruscsv.'";"";""';
      }
      #virus
      else
      {
        print qq(<td $cb><b><a href="/$module_name/vdb_search_main.cgi?search=on&virus=$hrow{'url_virus'}" title="$text{'VIRUS'}: $virus" target="_BLANK">$virusc</a></b></td>);
	$export_line .= ';"";"";"'.$viruscsv.'"';
      }
      print qq(  <td $cb title="$text{'FROM'}: $from">$fromc</td>
        <td $cb title="$text{'TO'}: $to">$toc</td>);
	
	if (&clamav_get_acl ('quarantine_resend') == 1 || 
	&clamav_get_acl ('quarantine_delete') == 1)
	{
	  print qq(<td $cb><input type="checkbox" name="quarantine_file$i" 
	                          value="$hrow{'base'}"></td>);
	}
	else
	{
	  print qq(<td></td>);
	}
	
        $export_line .= ";\"$fromcsv\";\"$tocsv\"\n";
        print F $export_line;
	print qq(</tr>);
  }

  close (F);

  print qq(</table>);
}

# clamav_escape_quotes ( $ )
# IN: the string to escape.
# OUT: a escaped string.
#
# Escape quotes in a string.
# 
sub clamav_escape_quotes ( $ )
{
  my $str = shift;

  $str =~ s/"/""/g;

  return $str;
}

# clamav_html_encode_quotes ( $ )
# IN: the string to encode.
# OUT: a encoded string.
#
# Encode quotes in a string.
# 
sub clamav_html_encode_quotes ( $ )
{
  my $str = shift;

  $str =~ s/"/&quot;/g;

  return $str;
}

# clamav_html_encode ( $ )
# IN: the string to encode.
# OUT: a encoded string.
#
# Encode a string.
# 
sub clamav_html_encode ( $ )
{
  my $str = shift;

  $str = HTML::Entities::encode ($str);
  $str =~ s/"/&quot;/g;

  return $str;
}

# clamav_print_javascript_check_uncheck_all ( $ $ )
# IN: index of the form in the page.
#     field name.
# OUT: -
#
# Print the necessary javascript to manage check/unckeck all feature.
# 
sub clamav_print_javascript_check_uncheck_all ( $ $ )
{
  my ($form, $name) = @_;
  
  print qq(
    <script language="javascript">
      function check_uncheck_all (value)
      {
        for (var i = 0; i < document.forms[$form].length; i++)
	  if (document.forms[$form][i].name.indexOf ('$name') >= 0)
	    document.forms[$form][i].checked = value;
      }
    </script>
  );
}

# clamav_format_date ( $ $ $ )
# IN: The days, month and year
# OUT: The formated date (YYYY-MM-DD)
#
# Format a date
# 
sub clamav_format_date ( $ $ $ )
{
  my ($day, $month, $year) = @_;
  my $date = '';
  
  $day = int ($day);
  $month = int ($month);
  $year = int ($year);

  return '' if ($day == 0 || $year == 0);

  $month++;
  $year += 2000 if ($year < 1000);

  $date = sprintf ('%u-%02u-%02u', $year, $month, $day);

  return $date;
}

# clamav_get_months_combo_options ( $ )
# IN: Default choice
# OUT: A buffer containing the SELECT options
#
# Build options for the SELECT tag with months
# 
sub clamav_get_months_combo_options ( $ )
{
  my $default = shift;
  my $buf = '';
  
  my $i = 0;
  foreach (split (/ /, $text{'MONTHS_LIST'}))
  {
    $buf .=
      "<option value=\"$i\"".
      (($i == $default) ? ' selected="selected"' : '').
      ">$_</option>\n";
    $i++;
  }

  return $buf;
}

# clamav_get_period_chooser ( $ $ $ $ $ $ )
# IN: Defaults day1, month1, year1, day2, month2 and year2
# OUT: -
# 
# Display fields to manage preriod
# 
sub clamav_get_period_chooser ( $ $ $ $ $ $ )
{
  my ($day1, $month1, $year1, $day2, $month2, $year2) = @_;
  
  # First period
  print "<table border=0><tr>";
  print qq(<td>$text{'FROM_PERIOD'}</td><td><input type="text" name="day1" size="2" maxlength="2" value="$day1"></td><td><select name="month1">);
  print &clamav_get_months_combo_options ($month1);
  print qq(</select></td><td><input type="text" name="year1" size="4" maxlength="4" value="$year1"></td><td>);
  print &date_chooser_button ('day1', 'month1', 'year1', 1);
  print "</td></tr><tr>";
  # Second period
  print qq(<td>$text{'TO_PERIOD'}</td><td><input type="text" name="day2" size="2" maxlength="2" value="$day2"></td><td><select name="month2">);
  print &clamav_get_months_combo_options ($month2);
  print qq(</select></td><td><input type="text" name="year2" size="4" maxlength="4" value="$year2"></td><td>);
  print &date_chooser_button ('day2', 'month2', 'year2', 1);
  print "</td></tr></table>";
}

# clamav_display_page_panel ( $ $ )
# IN: Current page.
#     Number of pages.
# OUT: -
#
# Display the navigation panel for quarantine list.
#
sub clamav_display_page_panel ( $ $ % )
{
  my ($current, $max, %infos) = @_;
  my $previous = 0;
  my $next = 0;
  my $limit = 0;
  my $url = '';

  # Do we need to paginate?
  return if ($max <= MAX_PAGE_ITEMS);

  $current = int ($current);
  $limit = $max / MAX_PAGE_ITEMS;
  $limit = ceil ($limit);
  $previous = $current - 1 if ($current > 0);
  $next = $current + 1;

  $url = 
    "search=1&" .
    "search_type=".&urlize($in{'search_type'})."&".
    "virus_name=".&urlize($in{'virus_name'})."&".
    "mail_from=".&urlize($in{'mail_from'})."&".
    "mail_to=".&urlize($in{'mail_to'})."&".
    "day1=$in{'day1'}&".
    "day2=$in{'day2'}&".
    "month1=$in{'month1'}&".
    "month2=$in{'month2'}&".
    "year1=$in{'year1'}&".
    "year2=$in{'year2'}";

  while (my ($k, $v) = each (%infos))
  {
    $url .= "&$k=".&urlize($v);
  }

  print qq(<p><table border="0" cellspacing="2" cellpadding="2" width="40%">);
  if ($current > 0)
  {
    print qq(<tr><td valign="top" align="center" $cb width="10%">);
    print qq(<a href="quarantine_main.cgi?cp=$previous&$url">);
    print qq($text{'PREVIOUS'}</a>);
  }
  else
  {
    print qq(<tr><td valign="top" align="center" width="10%">&nbsp;);
  };
  print qq(</td><td valign="top" align="center" nowrap>&nbsp;);

  my $i = 0;
  my $mask = 0;
  while ($i < $limit)
  {
    if (
      $i <= 3 ||
      ($i >= $current - 1 && $i <= $current + 1) ||
      $i >= $limit - 2)
    {
      if ($current == $i)
      {
        print '<b>'.($i + 1).'</b> ';
      }
      else
      {
        print qq(<a href="quarantine_main.cgi?cp=$i&$url">);
        print $i + 1;
        print qq(</a> );
      }
      $mask = 1;
    }
    elsif ($mask == 1)
    {
      print ' ... ';
      $mask = 0;
    }
    $i++;
  }

  if ($current < $limit - 1)
  {
    print qq(&nbsp;</td><td valign="top" align="center" $cb width="10%">);
    print qq(<a href="quarantine_main.cgi?cp=$next&$url">$text{'NEXT'}</a>);
  }
  else
  {
    print qq(</td><td valign="top" align="center" width="10%">&nbsp;);
  };
  print qq(
    </td></tr>
    </table></p>
  );
}

# clamav_footer ()
# IN: -
# OUT: -
#
# Display versions for both this module and clamav
# 
sub clamav_footer ()
{
  my $clamav_version = &clamav_get_version ();
  my $wbmclamav_version = $module_info{'version'};
  
  print qq(
    <i>ClamAV</i> <b>$clamav_version</b> / 
    <i>wbmclamav</i> <b>$wbmclamav_version</b>
  );
}

# clamav_check_deps ()
# IN: -
# OUT: -
#
# Check if all dependencies are ok for perl
# -> test them before with the "eval" function and add all bad
#    dependencies in the global %deps hash
#
sub clamav_check_deps ()
{
  # If no quarantine management, we do not need the following modules, so
  # remove them from the error list
  if ($config{'clamav_quarantine_soft'} == CS_NONE)
  {
    delete $deps{'Mail::SpamAssassin'};
    delete $deps{'Compress::Zlib'};
    delete $deps{'Getopt::Long'};
    delete $deps{'IO::File'};
    delete $deps{'Net::SMTP'};
    delete $deps{'Mail::Internet'};
    delete $deps{'GD'};
    delete $deps{'GD::Graph::lines'};
  }
  # For the moment, quarantine evolution graphes are ony available
  # for amavisd-new, mailscanner and qmailscanner quarantines
  elsif ($config{'clamav_quarantine_soft'} != CS_AMAVIS &&
         $config{'clamav_quarantine_soft'} != CS_MAILSCANNER &&
         $config{'clamav_quarantine_soft'} != CS_QMAILSCANNER)
  {
    delete $deps{'GD'};
    delete $deps{'GD::Graph::lines'};
  }
  # Only amavisd-new mbox quarantine is supported
  elsif ($config{'clamav_quarantine_soft'} != CS_AMAVIS)
  {
    delete $deps{'Mail::Mbox::MessageParser'};
  }

  return if (!%deps);
                                                                                
  print qq($text{'PERL_DEPS_ERROR'});
  print qq(<ul>);
  foreach my $mod (keys %deps) {print qq(<li><b>$mod</b></li>\n);}
  print qq(</ul>);
  
  &clamav_check_config_exit ('', 1);
}

# clamav_get_quarantine_infos ()
# IN: -
# OUT: a hash with quarantine informations (size, viruses count, spams count).
#
# Return informations about the quarantine repository.
# 
sub clamav_get_quarantine_infos ()
{
  my @data = ();
  my %infos = ();
  my $size = 0;
  my $viruses = 0;
  my $spams = 0;
  my $du = &has_command ('du');
  my %graph_data = ();

  $infos{'directory'} = $config{'clamav_quarantine'};
  $infos{'size'} = $text{'EMPTY'};
  $infos{'viruses'} = $text{'NONE'};
  $infos{'spams'} = $text{'NONE'};
  $infos{'badh'} = $text{'NONE'};
  $infos{'banned'} = $text{'NONE'};
  $infos{'graph_name'} = '';
    
  if (!&clamav_is_quarantine_repository_empty ())
  {
    $infos{'graph_name'} = 
      "$remote_user-quarantine_graph-".(time()).".png";
    $infos{'size'} = 
      (split (/ /, `$du -sh $config{'clamav_quarantine'}`))[0];

    # amavisd-new
    if (&clamav_is_amavisd_new ())
    {
      ($infos{'viruses'}, $infos{'spams'}, $infos{'badh'}, $infos{'banned'},
       %graph_data) = &quarantine_get_infos_amavisd_new ();
    }
    # mailscanner
    elsif (&clamav_is_mailscanner ())
    {
      ($infos{'viruses'}, $infos{'spams'}, %graph_data) = 
        &quarantine_get_infos_mailscanner ();
    }
    # qmailscanner
    elsif (&clamav_is_qmailscanner ())
    {
      ($infos{'viruses'}, $infos{'spams'}, %graph_data) = 
        &quarantine_get_infos_qmailscanner ();
    }
    # amavis-ng
    elsif (&clamav_is_amavis_ng ())
    {
      ($infos{'viruses'}, $infos{'spams'}) = &quarantine_get_infos_amavis_ng ();
    }
    # milter
    elsif (&clamav_is_milter ())
    {
      ($infos{'viruses'}, $infos{'spams'}) = &quarantine_get_infos_milter ();
    }

    # For the moment, quarantine evolution graph is only available
    # for amavisd-new, mailscanner and qmailscanner quarantines
    if (&clamav_is_amavisd_new () || 
        &clamav_is_qmailscanner () || 
        &clamav_is_mailscanner)
    {
      my @date = ();
      my @virus = ();
      my @spam = ();
      my @banned = ();
      my @badh = ();
      my $max = 0;
      my $viruscount = 0;
      my $spamcount = 0;
      my $bannedcount = 0;
      my $badhcount = 0;

      foreach my $k (sort keys %graph_data)
      {
        my $v = $graph_data{$k};
        push (@date, $k);
        push (@virus, $v->{'virus'});
        push (@spam, $v->{'spam'});
        push (@banned, $v->{'banned'});
        push (@badh, $v->{'badh'});
        $max = $v->{'virus'} if ($v->{'virus'} > $max);
        $max = $v->{'spam'} if ($v->{'spam'} > $max);
        $max = $v->{'banned'} if ($v->{'banned'} > $max);
        $max = $v->{'badh'} if ($v->{'badh'} > $max);
        $viruscount += $v->{'virus'};
        $spamcount += $v->{'spam'};
        $bannedcount += $v->{'banned'};
        $badhcount += $v->{'badh'};
      }
      ++$max while ($max % 10);
  
      @virus = () if (!$viruscount);
      @spam = () if (!$spamcount);
      @banned = () if (!$bannedcount);
      @badh = () if (!$badhcount);

      my $graph = new GD::Graph::lines (QG_WIDTH, QG_HEIGHT);
      $graph->set (
          title => "Quarantine evolution",
          x_label => 'Year/Month',
          x_label_position => 0,
          y_label => 'Number of E-Mails',
          text_space => 20,
          y_max_value => $max,
          y_tick_number => 10,
          x_all_ticks => 1,
          y_all_ticks => 10,
          x_label_skip => 0,
          bgclr => 'black',
          box_axis => 0,
          fgclr => 'black',
          show_values => 1,
          labelclr => 'green',
          axislabelclr => 'orange',
          legendclr => 'white',
          valuesclr => 'white',
          textclr => 'green',
          transparent => 0,
          logo => "$root_directory/$module_name/images/icon.gif",
          logo_position => 'UR'
      );
  
      if (&clamav_is_amavisd_new ())
      {
        @data = ([@date], [@virus], [@spam], [@banned], [@badh]);
        $graph->set_legend ('Viruses', 'Spams', 'Banned', 'Bad headers');
      }
      else
      {
        @data = ([@date], [@virus], [@spam]);
        $graph->set_legend ('Viruses', 'Spams');
      }

      my $gd = $graph->plot (\@data);
      if ($gd)
      {
        system (
          &has_command('rm').' -f '.
          "$root_directory/$module_name/tmp/".
          "$remote_user-quarantine_graph-*.png");
        open OUT, ">$root_directory/$module_name/tmp/".$infos{'graph_name'}
          or die "Couldn't open for output: $!";
        binmode (OUT);
        print OUT $gd->png ();
        close OUT;
      }
    }
  }

  return %infos;
}

# quarantine_get_infos_milter ()
# IN: -
# OUT: a hash with quarantine informations (viruses count, spams count).
#
# Return informations about the quarantine repository for clamav milter.
# 
sub quarantine_get_infos_milter ()
{
  my $viruses = 0;
  my $spams = 0;
  
  opendir (DIR, $config{'clamav_quarantine'});
  while (my $dir = readdir (DIR))
  {
    next if ($dir =~ /^\./);
    
    opendir (DIR1, "$config{'clamav_quarantine'}/$dir/");
    while (my $file = readdir (DIR1))
    {
      next if ($file =~ /^\./);
      $viruses++;
    };
    closedir (DIR1);
  }
  closedir (DIR);
  
  return ($viruses, $spams);
}

# quarantine_get_infos_amavis_ng ()
# IN: -
# OUT: a hash with quarantine informations (viruses count, spams count).
#
# Return informations about the quarantine repository for amavis ng.
# 
sub quarantine_get_infos_amavis_ng ()
{
  my @files = ();
  my $viruses = 0;
  my $spams = 0;
  my $i = 0;
  
  opendir (DIR, $config{'clamav_quarantine'});
  @files = readdir (DIR);
  closedir (DIR);

  for ($i = 0; $i < $#files + 1; $i += 2)
  {
    next if ($files[$i] eq '.');
    $viruses++;
  }
  
  return ($viruses, $spams);
}

# quarantine_get_infos_amavisd_new ()
# IN: -
# OUT: a hash with quarantine informations (viruses count, spams count,
#      bad headers count, banned count).
#
# Return informations about the quarantine repository for amavisd-new.
# 
sub quarantine_get_infos_amavisd_new ()
{
  my @files = ();
  my $viruses = 0;
  my $spams = 0;
  my $badh = 0;
  my $banned = 0;
  my $i = 0;
  my %data = ();
  my $mbox = 0;
  
  # If mbox format
  if (&clamav_is_mbox_format ($config{'clamav_quarantine'}))
  {
    my $filename = $config{'clamav_quarantine'};
    my $filehandle = new FileHandle ($filename);

    $mbox = 1;

    my $folder_reader =
      new Mail::Mbox::MessageParser( {
        'file_name' => $filename,
        'file_handle' => $filehandle,
      } );

    # This is the main loop. It's executed once for each email
    while (!$folder_reader->end_of_file ())
    {
      my $email = $folder_reader->read_next_email ();
      $files[$i++] = $$email;
    }
  }
  else
  {
    &get_all_files_in_dirs ($config{'clamav_quarantine'}, \@files);
  }

  for ($i = 0; $i < $#files + 1; $i++)
  {
    my $fdate = '';
    my $file = '';

    if ($mbox)
    {
      my %header = &clamav_get_email_header_values ($files[$i], 
                                                    qw(Date Delivered-To));
      $fdate = &UnixDate ($header{'Date'}, "%Y-%m-%d %H:%M");
      $file = $header{'Delivered-To'};
    }
    else
    {
      $fdate = strftime ('%y/%m', localtime ((stat ($files[$i]))[9]));
      $file = basename ($files[$i]);
    }

    # Prepare hash for quarantine evolution graph
    if (!exists ($data{$fdate}))
    {
      $data{$fdate} = {
        'virus' => 0,
        'badh' => 0,
        'banned' => 0,
        'spam' => 0
      };
    }

    # Virus
    if ($file =~ /^virus/)
    {
      ++$data{$fdate}{'virus'};
      ++$viruses;
    }
    # Badh
    if ($file =~ /^badh/)
    {
      ++$data{$fdate}{'badh'};
      ++$badh;
    }
    # Banned
    if ($file =~ /^banned/)
    {
      ++$data{$fdate}{'banned'};
      ++$banned;
    }
    # Spam
    elsif ($file =~ /^spam/)
    {
      ++$data{$fdate}{'spam'};
      ++$spams;
    }
  }

  return ($viruses, $spams, $badh, $banned, %data);
}

# quarantine_get_infos_mailscanner ()
# IN: -
# OUT: a hash with quarantine informations (viruses count, spams count).
#
# Return informations about the quarantine repository for MailScanner.
# 
sub quarantine_get_infos_mailscanner ()
{
  my %data = ();
  my $viruses = 0;
  my $spams = 0;
  my $tmp = '';
  
  opendir (DIR, $config{'clamav_quarantine'});
  while (my $dir = readdir (DIR))
  {
    next if ($dir =~ /^\./);
    
    opendir (DIR1, "$config{'clamav_quarantine'}/$dir/");
    while (my $dir1 = readdir (DIR1))
    {
      next if ($dir1 =~ /^\./) || ($dir1 eq 'spam');

      $is_spam = (-f "$config{'clamav_quarantine'}/$dir/spam/df$dir1");

      opendir (DIR2, "$config{'clamav_quarantine'}/$dir/$dir1/");
      while (my $file = readdir (DIR2))
      {
        next if ($file =~ /^\./);
        next if ($file !~ /^q/ && $file ne 'message');
	
        my $fdate = strftime ('%y/%m', localtime ((stat (
          "$config{'clamav_quarantine'}/$dir/$dir1/$file"))[9]));

        # Prepare hash for quarantine evolution graph
        if (!exists ($data{$fdate}))
        {
          $data{$fdate} = {
            'virus' => 0,
            'badh' => 0,
            'banned' => 0,
            'spam' => 0
          };
        }
  
        if ($is_spam)
        {
          ++$data{$fdate}{'spam'};
          ++$spams;
        }
        else
        {
          ++$data{$fdate}{'virus'};
          ++$viruses;
        }
      };
      closedir (DIR2);
    };
    closedir (DIR1);
  }

  return ($viruses, $spams, %data);
}

# quarantine_get_infos_qmailscanner ()
# IN: -
# OUT: a hash with quarantine informations (viruses count, spams count).
#
# Return informations about the quarantine repository for Qmailscanner.
# 
sub quarantine_get_infos_qmailscanner ()
{
  my @files = ();
  my $viruses = 0;
  my $spams = 0;
  my $i = 0;
  my %data = ();
  
  &get_match_files_in_dirs ($config{'clamav_quarantine'}, \@files, "\/new\/");

  for ($i = 0; $i < $#files + 1; $i++)
  {
    my %header = &clamav_get_email_header_values (
      $files[$i], qw(Subject From To Quarantine-Description X-Spam-Level)
    );

    if ($header{'X-Spam-Level'} || $header{'Quarantine-Description'})
    {
      my $fdate = strftime ('%y/%m', localtime ((stat ($files[$i]))[9]));

      # Prepare hash for quarantine evolution graph
      if (!exists ($data{$fdate}))
      {
        $data{$fdate} = {
          'virus' => 0,
          'spam' => 0
        };
      }

      if ($header{'X-Spam-Level'})
      {
        ++$data{$fdate}{'spam'};
        ++$spams;
      }
      elsif ($header{'Quarantine-Description'})
      {
        ++$data{$fdate}{'virus'};
        ++$viruses;
      }
    }
  }

  return ($viruses, $spams, %data);
}

# clamav_display_remote_actions ($ $ $ $)
# IN: hostname
#     port
#     clamav command
#     argument for clamav command if needed
# OUT: -
#
# display a HTML table
# 
sub clamav_display_remote_actions ($ $ $ $)
{
  my ($host, $port, $action, $arg) = @_;

  require "$root_directory/$module_name/data/clamav_remote_actions.pm";

  print qq(
    <table border="1">
      <tr><td $cb>$text{'HOST'}</td>
      <td><input type="text" name="host" value="$host"></td></tr>
      <tr><td $cb>$text{'PORT'}</td>
      <td><input type="text" name="port" value="$port"></td></tr>
      <tr><td $cb>$text{'COMMAND'}<br><select name="action">);

  foreach my $key (sort keys %clamav_remote_actions)
  {
    my $selected = ($key eq $action);
    my $name = sprintf ("$key - %s", ($clamav_remote_actions{$key} == 1) ?
                 "Argument needed ->" : "No argument");
    printf (qq(<option value="$key"%s>$name</option>),
      ($selected) ? ' selected="selected"' : '');
  }

  print qq(
    </select></td>
    <td valign="bottom"><input type="text" name="arg" value="$arg"></td></tr>
    </table>);
}

# clamav_value_is ( $ $ )
# IN: The variable to test, the value to test
# OUT: 1 if the variable is equal to the value of the given constant name
#
# Test if a given variable is equal to a module constant
# 
sub clamav_value_is
{
  my ($val, $const) = @_;
  my $ret = 0;

  eval ("\$ret = (\$val == $const);");

  return $ret;
}

# clamav_update_manual ()
# IN: -
# OUT: 1 if clamav update must be done manually by user.
#
# Check if the update must be done manually by the user
# 
sub clamav_update_manual
{
  return ($config{'clamav_refresh_use_cron'} == UP_MANUAL);
}

# clamav_join_from_url ( $ $ )
# IN: Begining of the variable to search in querystring, 1 if we must urlize.
# OUT: A URL string containing all name=values for the given key.
#
# Retreive all keys beginning with the given string in a URL.
# 
sub clamav_join_from_url
{
  my ($str, $e) = @_;
  my $args = '';
  my $esc = 1;

  $esc = $e if defined ($e);

  while (my ($k, $v) = each (%in))
  {
    next if $k !~ /^$str/;
    
    $args .= "$k=" .(($esc) ? &urlize($v) : $v)."&";
  }

  $args =~ s/.$//;

  return $args;
}

# clamav_system_ok ( $ )
# IN: Check for 'backup' or 'restore'
# OUT: True if the system has already been prepared to work with 
#      wbmclcmav.
#      
sub clamav_system_ok
{
  my $type = shift;
  my $ret = 0;

  if ($type eq 'backup')
  {
    $ret = (! -f $config{'clamav_init_restore_path'}.
                   '/wbmclamav_system_backups/.backup_flag');
  }
  elsif ($type eq 'restore')
  {
    $ret = (-f $config{'clamav_init_restore_path'}.
                 '/wbmclamav_system_backups/.backup_flag');
  }

  return $ret;
}

# clamav_backup_item_exists ( $ )
# IN: item (file or directory) to check
# OUT: 1 if item exists in backup repository
#
# Check if a item exists in the backup directory.
#
sub clamav_backup_item_exists ()
{
  my $i = shift;

  return(-e $config{'clamav_init_restore_path'}."/wbmclamav_system_backups/$i");
}

# clamav_system_backup ()
# IN: -
# OUT -
#
# Backup and empty if needed all system scripts that already are
# managing ClamAV. We need to do that in order to work with wbmclamav.
# 
sub clamav_system_backup
{
  my $cpath = 
    $config{'clamav_init_restore_path'}.'/wbmclamav_system_backups/';

  require "$root_directory/$module_name/data/system_files.pm";

  if ($gconfig{'os_type'} !~ /bsd/)
  {
    my $freshclam = $config{'clamav_freshclam_init_script'};
    
    &clamav_reactivate_system_file ($freshclam);
    
    if (-f '/var/lib/clamav/interface.webmon_NO')
    {
      move ('/var/lib/clamav/interface.webmon_NO',
            '/var/lib/clamav/interface');
    }
    if (-f '/var/lib/clamav/clamav-freshclam.webmin_NO')
    {
      move ('/var/lib/clamav/clamav-freshclam.webmin_NO',
            '/etc/cron.d/clamav-freshclam');
    }
  }

  make_path ($cpath);
  if (! -d $cpath)
  {
    &clamav_check_config_exit (sprintf ($text{'MSG_FATAL_ERROR_BACKUP_PATH'},
                                 $cpath));
  }

  while (my ($path, $empty) = each (%system_files))
  {
    next if (! -f "$path");
  
    $path =~ /^(.*)\/(.*)$/;
    my ($dir, $file) = ($1, $2);
    
    make_path ("$cpath/$dir");
    if (! -d "$cpath/$dir")
    {
      &clamav_check_config_exit (sprintf ($text{'MSG_FATAL_ERROR_BACKUP_PATH'},
                                   "$cpath/$dir"));
    }
    if (!copy ($path, "$cpath/$dir/"))
    {
      &clamav_check_config_exit (sprintf ($text{'MSG_FATAL_ERROR_BACKUP_FILE'},
                                   $path, "$cpath/$dir/$file"));
    }

    if ($empty)
    {
      open (H, '>', $path) || 
        &clamav_check_config_exit (
          sprintf ($text{'MSG_FATAL_ERROR_BACKUP_FILE_EMPTY'},
            "$cpath/$dir/$file"));
      print H 
        "# Deactivated by wbmclamav\n" .
        "# Backup file is : $cpath/$dir/$file\n";
      close (H);
    }
  }

  open (H, '>', "$cpath/.backup_flag"); close (H);
}

# clamav_first_backup ()
# IN: -
# OUT: -
#
# Return 1 if first backup
#
sub clamav_first_backup ()
{
  return !(-d $config{'clamav_init_restore_path'}.'/wbmclamav_system_backups');
}

# clamav_get_system_files ()
# IN: -
# OUT: -
#
# Return a hash with system files to backup/restore
# 
sub clamav_get_system_files
{
  require "$root_directory/$module_name/data/system_files.pm";

  return \%system_files;
}

# clamav_system_restore ( \@ )
# IN: A reference on a array containing files to restore. If this arg is empty
#     all files will be restored
#     1 if we are in webmin uninstall procedure
# OUT -
#
# Restore all system scripts that have been backuped by wbmclamav.
#
sub clamav_system_restore
{
  my ($files, $uninstall) = @_;
  my $cpath = $config{'clamav_init_restore_path'}.'/wbmclamav_system_backups/';

  require "$root_directory/$module_name/data/system_files.pm";
  
  if (!defined ($uninstall))
  {
    if (!&clamav_system_ok ('restore'))
    {
      &clamav_check_config_exit (
        sprintf ($text{'MSG_WARNING_RESTORE_BACKUP_FLAG'}, $cpath));
    }
  
    if (! -d "$cpath")
    {
      &clamav_check_config_exit (
        sprintf ($text{'MSG_FATAL_ERROR_RESTORE_PATH_NOEXIST'}, $cpath));
    }
  }

  foreach my $path (keys %system_files)
  {
    next if (defined ($files) && @$files && !grep /$path/, @$files);
    $path =~ /^(.*)\/(.*)$/;
    my ($dir, $file) = ($1, $2);
    
    # If source or destination do not exists anymore, do not bother
    next if (! -f "$cpath/$dir/$file" || ! -f $path);
 
    # Backup current system file before restoring file backuped by this module,
    # just in case something wrong happened
    copy ("$path/$file", "$path.clamav-backup-".time());

    # Restore file
    copy ("$cpath/$dir/$file", $path);
  }

  unlink ("$cpath/.backup_flag");
}

#################
#
sub clamav_debug ( $ $ )
{
  use Data::Dumper;
  my ($txt, $to_file) = @_;
  if ($to_file)
  {
    open (FH, '>>', '/tmp/clamav_debug.log');
    print FH Dumper(shift)."\n";
    close(FH);
  }
  else
  {
    print '<pre style="background:silver">'.Dumper($txt).'</pre>';
  }
}
#
#################

1;

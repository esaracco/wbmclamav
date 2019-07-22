#!/usr/bin/perl

# Copyright (C) 2003-2019
# Emmanuel Saracco <emmanuel@esaracco.fr>
#
# GNU GENERAL PUBLIC LICENSE

require './clamav-lib.pl';
&clamav_check_acl ('global_settings_view');
&ReadParse ();

my $msg;

# Clean temp if first access
if ($ENV{'REQUEST_METHOD'} eq 'GET')
{
  &clamav_clean_global_settings_tempfiles ();
}
else
{
  &clamav_check_acl ('global_settings_write');
}

&clamav_header ($text{'LINK_SETTINGS'});

print qq(<p>$text{'SETTINGS_DESCRIPTION'}</p>);
print qq(<p>$text{'SETTINGS_MULTIVALUED'}</p>);

if ($in{'next'})
{
  # Keep clamd status before update
  my $old_alive = &clamav_is_clamd_alive ();

  $error = &clamav_save_global_settings (1);
  $msg = qq(<p>);
  if ($error)
  {
    $msg .= qq("<p>$error<p><p/><b>$text{'MSG_CONFIGS_RESTORED'}</b>);
  }
  else
  {
    if (&clamav_is_clamd_alive () eq $old_alive)
    {
      $msg .= qq(<b>$text{'MSG_SUCCES_APPLY_GLOBAL_SETTINGS'}</b>);
    }
    else
    {
      $msg .= sprintf (qq(<b>$text{'MSG_ERROR_APPLY_GLOBAL_SETTINGS'}</b>),
                $config{'clamav_clamav_log'});
    }
  }
  $msg .= qq(</p>);
}
elsif ($ENV{REQUEST_METHOD} eq 'POST')
{
  # If there is a item to add
  if ($in{'nsclamav_add'} || $in{'nsfreshclam_add'})
  {
    $add_item_c = $in{'nsclamav_add_key'} if ($in{'nsclamav_add'});
    $add_item_f = $in{'nsfreshclam_add_key'} if ($in{'nsfreshclam_add'});
  }
  # If there is a item to delete
  else
  {
    $delete_item_c = &clamav_global_settings_get_delete_item ('clamav');
    $delete_item_f = &clamav_global_settings_get_delete_item ('freshclam');
  }
}

print qq(
  <ul>
    <li><a href="#clamav">$text{'SETTINGS_CLAMAV_TITLE'}</a></li>
    <li><a href="#freshclam">$text{'SETTINGS_FRESHCLAM_TITLE'}</a></li>
  </ul>
);

print qq(<form method="POST" action="$scriptname">);

print qq(<h2 id="clamav"><a href="#top">^</a> $text{'SETTINGS_CLAMAV_TITLE'}</h2>);
print $msg if ($msg);
if (&clamav_get_acl ('global_settings_write') == 1)
{
  print qq(<p><button type="submit" name="next" onclick="this.form.action+='#clamav'" class="btn btn-success">$text{'APPLY'}</button></p>);
}
&clamav_display_settings ('clamav', $add_item_c, $delete_item_c);

print qq(<h2 id="freshclam"><a href="#top">^</a> $text{'SETTINGS_FRESHCLAM_TITLE'}</h2>);
print $msg if ($msg);
if (&clamav_get_acl ('global_settings_write') == 1)
{
  print qq(<p><button type="submit" name="next" onclick="this.form.action+='#freshclam'" class="btn btn-success">$text{'APPLY'}</button></p>);
}
&clamav_display_settings ('freshclam', $add_item_f, $delete_item_f);

print qq(</form>);

print qq(<hr>);
&footer("", $text{'RETURN_INDEX_MODULE'});

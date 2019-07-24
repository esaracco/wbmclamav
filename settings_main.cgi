#!/usr/bin/perl

# Copyright (C) 2003-2019
# Emmanuel Saracco <emmanuel@esaracco.fr>
#
# GNU GENERAL PUBLIC LICENSE

require './clamav-lib.pl';
&clamav_check_acl ('global_settings_view');
&ReadParse ();

my ($_success, $_error) = ('', '');

&clamav_header ($text{'LINK_SETTINGS'});

print qq(<p>$text{'SETTINGS_DESCRIPTION'}</p>);
print qq(<p>$text{'SETTINGS_MULTIVALUED'}</p>);

if (defined($in{'next'}))
{
  &clamav_check_acl ('global_settings_write');

  # Keep clamd status before update
  my $old_alive = &clamav_is_clamd_alive ();

  $error = &clamav_save_global_settings (1);
  if ($error)
  {
    $_error = "<b>$error</b><p/>$text{'MSG_CONFIGS_RESTORED'}";
  }
  else
  {
    if (&clamav_is_clamd_alive () eq $old_alive)
    {
      $_success = $text{'MSG_SUCCES_APPLY_GLOBAL_SETTINGS'};
    }
    else
    {
      $_error = sprintf ($text{'MSG_ERROR_APPLY_GLOBAL_SETTINGS'},
                  $config{'clamav_clamav_log'});
    }
  }
}
# If there is a item to add
elsif (defined($in{'nsclamav_add'}) || defined($in{'nsfreshclam_add'}))
{
  &clamav_check_acl ('global_settings_write');

  $add_item_c = $in{'nsclamav_add_key'} if (defined($in{'nsclamav_add'}));
  $add_item_f = $in{'nsfreshclam_add_key'} if (defined($in{'nsfreshclam_add'}));
}
# If there is a item to delete
elsif (($delete_item_c = &clamav_global_settings_get_delete_item ('clamav')) ||
       ($delete_item_f = &clamav_global_settings_get_delete_item ('freshclam')))
{
  &clamav_check_acl ('global_settings_write');
}
# Clean temp if first access
else
{
  &clamav_clean_global_settings_tempfiles ();
}

my $btn_class = ($add_item_c || $add_item_f ||
                 $delete_item_c || $delete_item_f) ? 'warning' : 'success';

print qq(
  <ul>
    <li><a href="#clamav">$text{'SETTINGS_CLAMAV_TITLE'}</a></li>
    <li><a href="#freshclam">$text{'SETTINGS_FRESHCLAM_TITLE'}</a></li>
  </ul>
);

print qq(<form method="POST" action="$scriptname">);

print qq(<h2 id="clamav"><a href="#top"><sup><i class="fa fa-fw fa-caret-up"></i></sup></a> $text{'SETTINGS_CLAMAV_TITLE'}</h2>);

if (&clamav_get_acl ('global_settings_write') == 1)
{
  print qq(<p/><div><button type="submit" name="next" class="btn btn-$btn_class ui_form_end_submit"><i class="fa fa-fw fa-check-circle-o"></i> <span>$text{'APPLY'}</span></button></div><p/>);
}
&clamav_display_settings ('clamav', $add_item_c, $delete_item_c);

print qq(<h2 id="freshclam"><a href="#top"><sup><i class="fa fa-fw fa-caret-up"></i></sup></a> $text{'SETTINGS_FRESHCLAM_TITLE'}</h2>);

if (&clamav_get_acl ('global_settings_write') == 1)
{
  print qq(<p/><div><button type="submit" name="next" class="btn btn-$btn_class ui_form_end_submit"><i class="fa fa-fw fa-check-circle-o"></i> <span>$text{'APPLY'}</span></button></div><p/>);
}
&clamav_display_settings ('freshclam', $add_item_f, $delete_item_f);

print qq(</form>);

&clamav_footer ('', $text{'RETURN_INDEX_MODULE'}, $_success, $_error);

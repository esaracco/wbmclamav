#!/usr/bin/perl

# Copyright (C) 2003-2019
# Emmanuel Saracco <emmanuel@esaracco.fr>
#
# GNU GENERAL PUBLIC LICENSE

use lib './lib';
use ClamavConstants;

require './clamav-lib.pl';
&clamav_check_acl ('quarantine_view');
&ReadParse ();

my $cp = $in{'cp'};
my $maxdays = $in{'maxdays'};
my $search_type = $in{'search_type'};
my $old_search_type = $in{'old_search_type'};
my $search_type_virus = ($search_type eq 'virus' || !$search_type);
my $search_type_spam = ($search_type eq 'spam');
my %quarantine_infos = ();
my $msg = '';

$cp = 0 if ($old_search_type ne '');

if (defined($in{'resend'}))
{
  my $args = &clamav_join_from_url ('quarantine_file');
  if ($args)
  {
    &redirect (
      "/$module_name/quarantine_resend.cgi?" .
      'notaspam=1&'.
      'deleteafter=1&'.
      'newto=1&'.
      $args);
  }

  delete $in{'resend'};
}
elsif (defined($in{'export'}))
{
  &clamav_download (
   "$config{'clamav_working_path'}/.clamav/$remote_user/quarantine-export.csv");
}

&clamav_header ($text{'LINK_QUANRANTINE_PAGE'});

print qq(
  <form action="$scriptname" method="post" id="quarantine-result">
  <input type="hidden" name="cp" value="$cp">
  <input type="hidden" name="old_search_type" value="$search_type">);

&clamav_quarantine_main_check_config ();

if (defined($in{'next'}))
{
  if ($in{'nopurge'} eq 'on')
  {
    $maxdays = '';
    &clamav_delete_cron ('purge');
    $msg = qq(<p><b>$text{'MSG_SUCCESS_QUARANTINE_CRON_UPDATE'}</b></p>);
  }
  else
  {
    if ($maxdays and $maxdays !~ /^[0-9]+$/)
    {
        $maxdays = 0;
    
        $msg = qq(<p><b>$text{'MSG_ERROR_QUARANTINE_UPDATE_MAXDAYS'}</b></p>);
    }
    else
    {
      my $hour = $in{'hour'};

      $hour = "*/$hour" if (defined($in{'every_hours'}) && $hour);
      &clamav_set_cron_purge ($hour, $in{'day'}, $maxdays);
      $msg = qq(<p><b>$text{'MSG_SUCCESS_QUARANTINE_CRON_UPDATE'}</b></p>);
    }
  }
}
elsif (defined($in{'resend'}))
{
  $msg = qq(<p><b>$text{'MSG_SUCCESS_STATUS_RESEND'}</b></p>);
}
elsif (defined($in{'delete'}))
{
  my $ok = 1;
  foreach my $key (keys %in)
  {
    if ($key =~ /quarantine_file/)
    {
      $ok = 0 if (!&clamav_remove_email ($in{$key}));
    }
  }

  $msg = ($ok) ? 
    qq(<p><b>$text{'MSG_SUCCESS_STATUS_REMOVE'}</b></p>) :
    qq(<p><b>$text{'MSG_ERROR_STATUS_REMOVE'}</b></p>);
}
elsif (defined($in{'delete_all'}))
{
  $res = &clamav_purge_quarantine ();
  if ($res != OK)
  {
    $msg = sprintf (qq(
      <b>$text{'MSG_ERROR_STATUS_PURGE_ALL'}</b>
      <p />
      <blockquote>
        <b>Message</b>: %s
      </blockquote>
     ), 
     $clamav_error);
  }
  else
  {
    $msg = qq(<p><b>$text{'MSG_SUCCESS_STATUS_PURGE_ALL'}</b></p>);
  }
}

if (!%in || !defined($in{'directory'}))
{
  %quarantine_infos = &clamav_get_quarantine_infos ();
}
else
{
  %quarantine_infos = ();
  foreach my $item (qw(directory size viruses spams badh banned graph_name))
  {
    $quarantine_infos{$item} = $in{$item};
  }
}

print qq(<div>);
print qq(<button type="submit" name="refresh" class="btn btn-success">$text{'QUARANTINE_REFRESH_STATS'}</button>);

# Quarantine evolution graph (amavisd-new, mailscanner and qmailscanner only)
if (&clamav_is_amavisd_new () || 
    &clamav_is_qmailscanner () || 
    &clamav_is_mailscanner ())
{
  print qq(<p/>);
  if ($quarantine_infos{'graph_name'})
  {
    print qq(&nbsp;<a href="#" onclick="document.getElementById('graph').style.display = (document.getElementById('graph').style.display == 'none') ? 'block' : 'none';return false">$text{'QUARANTINE_SHOWHIDE_GRAPH'}</a>);
  }
  print qq(<p/><img id="graph" style="display:none" src="/$module_name/tmp/$quarantine_infos{'graph_name'}"/>);
}
print qq(<div>);

# Global quarantine data
print qq(<p/><table>);
printf qq(
  <tr><td><i>$text{'QUARANTINE_DIRECTORY'}</i></td><td><b>%s</b></td></tr>
  <tr><td><i>$text{'QUARANTINE_SIZE'}</i></td><td><b>%s</b></td></tr>
  <tr><td><i>$text{'QUARANTINE_VIRUSES'}</i></td><td><b>%s</b></td></tr>
), $quarantine_infos{"directory"}, $quarantine_infos{"size"}, $quarantine_infos{"viruses"};
if (
  &clamav_is_amavisd_new () || 
  &clamav_is_mailscanner () ||
  &clamav_is_qmailscanner ()) 
{
  printf qq(<tr><td><i>$text{'QUARANTINE_SPAMS'}</i></td><td><b>%s</b>
    </td></tr>),
    $quarantine_infos{'spams'};
}
if (&clamav_is_amavisd_new ())
{
   printf qq(<tr><td><i>$text{'QUARANTINE_BADHEADERS'}</i></td><td><b>%s</b>
     </td></tr>),
     $quarantine_infos{'badh'};
   printf qq(<tr><td><i>$text{'QUARANTINE_BANNED'}</i></td><td><b>%s</b>
     </td></tr>),
     $quarantine_infos{'banned'};
}
print qq(</table>);

print qq(<p/><p>$text{'QUARANTINE_PAGE_DESCRIPTION'}</p>);

print qq(<h2>$text{'QUARANTINE_CLEANING'}</h2>);

if (&clamav_get_acl ('quarantine_delete') == 1)
{
  print qq(<p><button type="submit" name="delete_all" class="btn btn-success">$text{'PURGE_QUARANTINE_NOW'}</button></p>);
}

print qq(<p>$text{'QUARANTINE_CRON_DESCRIPTION'}</p>);

print $msg;

@cron_line = &clamav_get_cron_settings ('purge');
$checked = (@cron_line) ? '' : ' checked="checked"';

print &clamav_cron_settings_table($cron_line[1]||0, $cron_line[4]||7, $checked);
$maxdays = $cron_line[8] if ($maxdays eq '' && $cron_line[8]);

# maxdays
printf (qq(<p id="max-days"%s>), ($checked)?' class="disabled"':'');
print qq($text{'DELETE_MAX_DAYS'} <input type="text" name="maxdays" size="2" value="$maxdays"> $text{'DAYS'});
print qq(</p>);

# npurge
print qq(<p>);
print qq(<input type="checkbox" id="nopurgeid" name="nopurge" onchange="document.getElementById('cron-frequency').className=document.getElementById('max-days').className=(this.checked)?'disabled':''" value="on"$checked>);
print qq( <label for="nopurgeid">$text{'QUARANTINE_PURGE_NEVER'}</label>);
print qq(</p>);

print qq(<p>);
if (&clamav_get_acl ('quarantine_delete') == 1)
{
  print qq(<button type="submit" name="next" class="btn btn-success">$text{'APPLY'}</button>);
}
print qq(</p>);

print qq(<h2>$text{'QUARANTINE_RESEARCH'}</h2>);

if (defined $in{'resended'})
{
  if (defined ($in{'errstr'}) && $in{'errstr'} ne '')
  {
    $msg = sprintf (qq(
      <p><b>$text{'MSG_ERROR_STATUS_RESEND'}</b></p>
      <p>
      <blockquote>
        <b>File</b>: %s<br>
        <b>Message</b>: %s
      </blockquote>
      </p>),
      $in{'errfile'},
      $in{'errstr'}
    );
  }
  else
  {
    $msg = qq(<p><b>$text{'MSG_SUCCESS_STATUS_RESEND'}</b></p>);
  }
}
elsif (defined $in{'removed'})
{
  $msg = qq(<p><b>$text{'MSG_SUCCESS_STATUS_REMOVE'}</b></p>);
}

print $msg;

print qq(<p>$text{'QUARANTINE_RESEARCH_DESCRIPTION'}</p>);

while (my ($k, $v) = each (%quarantine_infos))
{
  print qq(<input type="hidden" name="$k" value="$v"/>);
}

print qq(<table border=0 bgcolor="silver">);
if (
  &clamav_is_amavisd_new () || 
  &clamav_is_mailscanner () || 
  &clamav_is_qmailscanner ())
{
  print qq(<tr><td $cb><b>$text{'TYPE'}</b>:</td><td>);
  print &clamav_display_combo_quarantine_items_types ($search_type);
  print qq(</td></tr>);
}
else
{
  print qq(<input type="hidden" name="search_type" value="virus">);
}
if (!(
  &clamav_is_milter () || 
  &clamav_is_mailscanner () || 
  &clamav_is_qmailscanner ()))
  {print qq(<tr><td $cb><b>$text{'VIRUS'}</b>:</td><td><input type="text" name="virus_name" value="$in{'virus_name'}"></td></tr>)}
else
  {print qq(<input type="hidden" name="virus_name" value="">)}

print qq(<tr><td $cb><b>$text{'SENDER'}</b>:</td><td><input type="text" name="mail_from" value="$in{'mail_from'}"></td></tr>
  <tr><td $cb><b>$text{'RECIPIENT'}</b>:</td><td><input type="text" name="mail_to" value="$in{'mail_to'}"></td></tr>
  <tr><td $cb valign="top"><b>$text{'PERIOD'}</b>:</td><td colspan="2" nowrap valign="top">);
&clamav_get_period_chooser ($in{'day1'}, $in{'month1'}, $in{'year1'}, $in{'day2'}, $in{'month2'}, $in{'year2'});
print qq(
  </td></tr>
  <tr><td colspan="2"><p/><button type="submit" class="btn btn-success" name="search">$text{'SEARCH'}</button></td></tr>
  </table>
  <p/>
);

# if form submit, do the quarantine search
if (defined($in{'search'}))
{
  if (&clamav_is_quarantine_repository_empty ())
  {
    print qq(<p><b>$text{'LINK_QUANRANTINE_EMPTY_PAGE'}</b></p>);
  }
  else
  {
    # if clamav-milter is installed
    if (&clamav_is_milter ())
    {
      $page_count = &clamav_print_quarantine_table_milter (
        $search_type,
        $cp,
        $in{'virus_name'},
        $in{'mail_from'}, $in{'mail_to'}, 
	$in{'day1'}, $in{'month1'}, $in{'year1'}, 
	$in{'day2'}, $in{'month2'}, $in{'year2'});
    }
    # if mailscanner is installed
    elsif (&clamav_is_mailscanner ())
    {
      $page_count = &clamav_print_quarantine_table_mailscanner (
        $search_type,
        $cp,
        $in{'virus_name'},
        $in{'mail_from'}, $in{'mail_to'}, 
	$in{'day1'}, $in{'month1'}, $in{'year1'}, 
	$in{'day2'}, $in{'month2'}, $in{'year2'});
    }
    # if amavis-ng is installed
    elsif (&clamav_is_amavis_ng ())
    {
      $page_count = &clamav_print_quarantine_table_amavis_ng (
        $search_type,
        $cp,
        $in{'virus_name'},
        $in{'mail_from'}, $in{'mail_to'}, 
	$in{'day1'}, $in{'month1'}, $in{'year1'}, 
	$in{'day2'}, $in{'month2'}, $in{'year2'});
    }
    # if amavisd-new is installed
    elsif (&clamav_is_amavisd_new ())
    {
      $page_count = &clamav_print_quarantine_table_amavisd_new (
        $search_type,
        $cp,
        $in{'virus_name'},
        $in{'mail_from'}, $in{'mail_to'}, 
	$in{'day1'}, $in{'month1'}, $in{'year1'}, 
	$in{'day2'}, $in{'month2'}, $in{'year2'});
    }
    # if qmailscanner is installed
    elsif (&clamav_is_qmailscanner ())
    {
      $page_count = &clamav_print_quarantine_table_qmailscanner (
        $search_type,
        $cp,
        $in{'virus_name'},
        $in{'mail_from'}, $in{'mail_to'}, 
	$in{'day1'}, $in{'month1'}, $in{'year1'}, 
	$in{'day2'}, $in{'month2'}, $in{'year2'});
    }
  }

  &clamav_display_page_panel ($cp, $page_count, %quarantine_infos);
}

print qq(</form>);
  
print qq(<hr/>);
&footer('', $text{'RETURN_INDEX_MODULE'});

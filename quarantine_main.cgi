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

my ($_success, $_error, $_info) = ('', '', '');
my $cp = $in{'cp'};
my $maxdays = $in{'maxdays'};
my $search_type = $in{'search_type'};
my $old_search_type = $in{'old_search_type'};
my $search_type_virus = ($search_type eq 'virus' || !$search_type);
my $search_type_spam = ($search_type eq 'spam');
my %quarantine_infos = ();

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

&clamav_quarantine_main_check_config ();

print qq(
  <form action="$scriptname" method="post" id="quarantine-result">
  <input type="hidden" name="cp" value="$cp">
  <input type="hidden" name="old_search_type" value="$search_type">);

if (defined($in{'next'}))
{
  if ($in{'nopurge'} eq 'on')
  {
    $maxdays = '';
    &clamav_delete_cron ('purge');
    $_success = $text{'MSG_SUCCESS_QUARANTINE_CRON_UPDATE'};
  }
  else
  {
    if ($maxdays and $maxdays !~ /^[0-9]+$/)
    {
        $maxdays = 0;
    
        $_error = $text{'MSG_ERROR_QUARANTINE_UPDATE_MAXDAYS'};
    }
    else
    {
      my $hour = $in{'hour'};

      $hour = "*/$hour" if (defined($in{'every_hours'}) && $hour);
      &clamav_set_cron_purge ($hour, $in{'day'}, $maxdays);
      $_success = $text{'MSG_SUCCESS_QUARANTINE_CRON_UPDATE'};
    }
  }
}
elsif (defined($in{'resend'}))
{
  $_success = $text{'MSG_SUCCESS_STATUS_RESEND'};
}
elsif (defined($in{'delete'}))
{
  my $ok = 1;

  while (my ($k, $v) = each (%in))
  {
    next if ($k !~ /quarantine_file/);
    $ok = &clamav_remove_email ($v);
  }

  if ($ok)
  {
    $_success = $text{'MSG_SUCCESS_STATUS_REMOVE'};
  }
  else
  {
    $_error = $text{'MSG_ERROR_STATUS_REMOVE'};
  }
}
elsif (defined($in{'delete_all'}))
{
  $res = &clamav_purge_quarantine ();
  if ($res != OK)
  {
    $_error = sprintf (qq(
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
    $_success = $text{'MSG_SUCCESS_STATUS_PURGE_ALL'};
  }
}

if (!$in || (!$in{'next'} && !$in{'search'}))
{
  %quarantine_infos = &clamav_get_quarantine_infos ();

  if ($quarantine_infos{'empty'})
  {
    $_info = $text{'MSG_QUARANTINE_IS_EMPTY'};
  }
  elsif (defined($in{'refresh'}))
  {
    $_success = $text{'QUARANTINE_STATS_REFRESHED'};
  }
}
else
{
  foreach my $item (qw(directory size graph_name empty
                       virus spam badh banned))
  {
    $quarantine_infos{$item} = $in{$item};
  }
}

while (my ($k, $v) = each (%quarantine_infos))
{
  print qq(<input type="hidden" name="$k" value="$v"/>);
}

print qq(<div>);
print qq(<button type="submit" name="refresh" class="btn btn-success ui_form_end_submit"><i class="fa fa-fw fa-refresh"></i> <span>$text{'QUARANTINE_REFRESH_STATS'}</span></button>);

# Quarantine evolution graph (amavisd-new, mailscanner and qmailscanner only)
if (&clamav_is_amavisd_new () || 
    &clamav_is_qmailscanner () || 
    &clamav_is_mailscanner ())
{
  print qq(<p/>);
  if ($quarantine_infos{'graph_name'} &&
      -f "tmp/$quarantine_infos{'graph_name'}")
  {
    print qq(<a class="btn btn-inverse btn-tiny ui_link_replaced" href="#" onclick="if (document.getElementById('graph').style.display == 'none'){document.getElementById('graph').style.display = 'block';HTMLClassReplace(document.getElementById('up-down'), 'fa-caret-right', 'fa-caret-down')} else {document.getElementById('graph').style.display = 'none';HTMLClassReplace(document.getElementById('up-down'), 'fa-caret-down', 'fa-caret-right')} return false"><i id="up-down" class="fa fa-fw fa-lg fa-caret-right"></i>$text{'QUARANTINE_SHOWHIDE_GRAPH'}</a>);
  }
  print qq(<p/><img id="graph" style="display:none" src="tmp/$quarantine_infos{'graph_name'}"/>);
}
print qq(</div>);

# Global quarantine data
print qq(<p/><table class="clamav keys-values">);
my $qtype = (-f $quarantine_infos{"directory"}) ?
              $text{'QUARANTINE_FILE'} : $text{'QUARANTINE_DIRECTORY'};
printf qq(
  <tr><td>$qtype:</td><td>%s</td></tr>
  <tr><td>$text{'QUARANTINE_SIZE'}:</td><td>%s</td></tr>
  <tr><td>$text{'QUARANTINE_VIRUSES'}:</td><td>%s</td></tr>
), $quarantine_infos{'directory'}, $quarantine_infos{'size'}, $quarantine_infos{'virus'};
if (
  &clamav_is_amavisd_new () || 
  &clamav_is_mailscanner () ||
  &clamav_is_qmailscanner ()) 
{
  printf qq(<tr><td>$text{'QUARANTINE_SPAMS'}:</td><td>%s</td></tr>),
    $quarantine_infos{'spam'};
}
if (&clamav_is_amavisd_new ())
{
   printf qq(<tr><td>$text{'QUARANTINE_BADHEADERS'}:</td><td>%s</td></tr>),
     $quarantine_infos{'badh'};
   printf qq(<tr><td>$text{'QUARANTINE_BANNED'}:</td><td>%s</td></tr>),
     $quarantine_infos{'banned'};
}
print qq(</table>);

print qq(<p/><p>$text{'QUARANTINE_PAGE_DESCRIPTION'}</p>);

print qq(<h2>$text{'QUARANTINE_CLEANING'}</h2>);

if (&clamav_get_acl ('quarantine_delete') == 1 && !$quarantine_infos{'empty'})
{
  print qq(<p/><div><button type="submit" name="delete_all" class="btn btn-danger ui_form_end_submit"><i class="fa fa-fw fa-trash"></i> <span>$text{'PURGE_QUARANTINE_NOW'}</span></button></div><p/>);
}

print qq(<p>$text{'QUARANTINE_CRON_DESCRIPTION'}</p>);

@cron_line = &clamav_get_cron_settings ('purge');
$checked = (@cron_line) ? '' : ' checked="checked"';

print &clamav_cron_settings_table($cron_line[1]||0, $cron_line[4]||7, $checked);
$maxdays = $cron_line[8] if ($maxdays eq '' && $cron_line[8]);

# maxdays
printf (qq(<p/><p id="max-days"%s>), ($checked)?' class="disabled"':'');
print qq($text{'DELETE_MAX_DAYS'} <input type="text" name="maxdays" size="2" onchange="HTMLClassReplace(document.getElementById('apply'), 'btn-success', 'btn-warning')" value="$maxdays"> $text{'DAYS'});
print qq(</p>);

# npurge
print qq(<p>);
print qq(<input type="checkbox" id="nopurgeid" name="nopurge" onchange="HTMLClassReplace(document.getElementById('apply'), 'btn-success', 'btn-warning');if(this.checked){HTMLClassAdd(document.getElementById('cron-frequency'), 'disabled');HTMLClassAdd(document.getElementById('max-days'), 'disabled')}else{HTMLClassRemove(document.getElementById('cron-frequency'), 'disabled');HTMLClassRemove(document.getElementById('max-days'), 'disabled')}" value="on"$checked>);
print qq( <label for="nopurgeid">$text{'QUARANTINE_PURGE_NEVER'}</label>);
print qq(</p>);

print qq(<p/>);
if (&clamav_get_acl ('quarantine_delete') == 1)
{
  print qq(<div><button type="submit" name="next" id="apply" class="btn btn-success ui_form_end_submit"><i class="fa fa-fw fa-check-circle-o"></i> <span>$text{'APPLY'}</span></button></div>);
}

if (!$quarantine_infos{'empty'})
{
  print qq(<h2>$text{'QUARANTINE_RESEARCH'}</h2>);
  
  if (defined $in{'resended'})
  {
    if (defined ($in{'errstr'}) && $in{'errstr'} ne '')
    {
      $_error =
        $text{'MSG_ERROR_STATUS_RESEND'}.
        ' [<b>file</b>: '.$in{'errfile'}.', <b>message</b>: '.$in{'errfile'}.']';
    }
    else
    {
      $_success = $text{'MSG_SUCCESS_STATUS_RESEND'};
    }
  }
  elsif (defined $in{'removed'})
  {
    $_success = $text{'MSG_SUCCESS_STATUS_REMOVE'};
  }
  
  print qq(<p>$text{'QUARANTINE_RESEARCH_DESCRIPTION'}</p>);
  
  print qq(<table class="clamav keys-values header">);
  print qq(<tr><td colspan=2>Filtres</td></tr>);
  if (
    &clamav_is_amavisd_new () || 
    &clamav_is_mailscanner () || 
    &clamav_is_qmailscanner ())
  {
    print qq(<tr><td>$text{'TYPE'}: </td><td>);
    print &clamav_display_combo_quarantine_items_types (
            $search_type, \%quarantine_infos);
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
  {
    print qq(<tr><td>$text{'VIRUS'}: </td><td><input type="text" name="virus_name" value="$in{'virus_name'}"></td></tr>);
  }
  else
  {
    print qq(<input type="hidden" name="virus_name" value="">);
  }
  
  print qq(<tr><td>$text{'SENDER'}: </td><td><input type="text" name="mail_from" value="$in{'mail_from'}"></td></tr>
    <tr><td>$text{'RECIPIENT'}: </td><td><input type="text" name="mail_to" value="$in{'mail_to'}"></td></tr>
    <tr><td>$text{'PERIOD'}: </td><td colspan="2" nowrap>);
  &clamav_get_period_chooser ($in{'day1'}, $in{'month1'}, $in{'year1'}, $in{'day2'}, $in{'month2'}, $in{'year2'});
  print qq(
    </td></tr>
    <tr><td colspan="2" class="control"><div><button type="submit" class="btn btn-success ui_form_end_submit" name="search"><i class="fa fa-fw fa-search"></i> <span>$text{'SEARCH'}</span></button></div></td></tr>
    </table>
    <p/>
  );
  
  # if form submit, do the quarantine search
  if (defined($in{'search'}))
  {
    if ($quarantine_infos{'empty'})
    {
      $_info = $text{'MSG_QUARANTINE_IS_EMPTY'};
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
  
      if (!$page_count)
      {
        $_info = $text{'NO_RESULT_QUARANTINE'};
      }
      else
      {
        &clamav_display_page_panel ($cp, $page_count, %quarantine_infos);
      }
    }
  }
}

print qq(</form>);

&clamav_footer ('', $text{'RETURN_INDEX_MODULE'}, $_success, $_error, $_info);

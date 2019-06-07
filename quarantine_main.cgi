#!/usr/bin/perl

# Copyright (C) 2003-2008
# Emmanuel Saracco <esaracco@users.labs.libre-entreprise.org>
# Easter-eggs <http://www.easter-eggs.com>
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
&clamav_check_acl ('quarantine_view');
&ReadParse ();

my $cp = $in{'cp'};
my $maxdays = $in{'maxdays'};
my $search_type = $in{'search_type'};
my $old_search_type = $in{'old_search_type'};
my $search_type_virus = ($search_type eq 'virus');
my $search_type_spam = ($search_type eq 'spam');
my %quarantine_infos = ();
my $msg = '';
$search_type_virus = 1 if ($search_type eq '');
$cp = 0 if ($old_search_type ne '');

if ($in{"resend"})
{
  my $args = &clamav_join_from_url ("quarantine_file");
  
  &redirect (
    "/$module_name/quarantine_resend.cgi?" .
    "notaspam=1&" .
    "deleteafter=1&" .
    "newto=1&" .
    $args) if ($args);

  delete $in{'resend'};
}
elsif ($in{'export'})
{
  my $dir = "$config{'clamav_working_path'}/.clamav/$remote_user";
  &clamav_download ("$dir/quarantine-export.csv");
}

&header($text{'FORM_TITLE'}, "", undef, 1, 0);
print "<hr>\n";

print qq(
  <form action="$scriptname" method="post">
  <input type="hidden" name="cp" value="$cp">
  <input type="hidden" name="old_search_type" value="$search_type">);

&clamav_quarantine_main_check_config ();

if ($in{'next'})
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

      $hour = "*/$hour" if ($in{'every_hours'} and $in{'hour'});
      &clamav_set_cron_purge ($hour, $in{'day'}, $maxdays);
      $msg = qq(<p><b>$text{'MSG_SUCCESS_QUARANTINE_CRON_UPDATE'}</b></p>);
    }
  }
}
elsif ($in{'resend'})
{
  $msg = qq(<h3>$text{'MSG_SUCCESS_STATUS_RESEND'}</h3>);
}
elsif ($in{'delete'})
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
    qq(<h3>$text{'MSG_SUCCESS_STATUS_REMOVE'}</h3>) :
    qq(<h3>$text{'MSG_ERROR_STATUS_REMOVE'}</h3>);
}
elsif ($in{'delete_all'})
{
  $res = &clamav_purge_quarantine ();
  if (!&clamav_value_is ($res, "OK"))
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
    $msg = qq(<h3>$text{'MSG_SUCCESS_STATUS_PURGE_ALL'}</h3>);
  }
}

if (!%in || $in{'refresh'} || $in{'delete_all'})
{
  %quarantine_infos = &clamav_get_quarantine_infos ();
}
else
{
  %quarantine_infos = ();
  $quarantine_infos{$_} = $in{$_} 
    foreach (qw(directory size viruses spams badh banned graph_name));
}

print qq(<h1>$text{'QUARANTINE_PAGE_TITLE'}</h1>);

# Quarantine evolution graph (amavisd-new, mailscanner and qmailscanner only)
if (&clamav_is_amavisd_new () || 
    &clamav_is_qmailscanner () || 
    &clamav_is_mailscanner ())
{
  print qq(<table><tr><td>);
  if  (%in && !$in{'refresh'} && !$in{'delete_all'}) {print qq(<input type="submit" name="refresh" value="$text{'QUARANTINE_REFRESH_STATS'}"/>)}
  if ($quarantine_infos{'graph_name'}) {print qq(&nbsp;<input type="button" onclick="document.getElementById('graph').style.display = (document.getElementById('graph').style.display == 'none') ? 'block' : 'none'" value="$text{'QUARANTINE_SHOWHIDE_GRAPH'}"></td></tr>
<tr style="background-color:black;border: 1px solid black;display:none;" id="graph"><td><img src="/$module_name/tmp/$quarantine_infos{'graph_name'}"/></td></tr>);}
print qq(</table>);
}
elsif (%in && !$in{'refresh'} && !$in{'delete_all'})
{
  print qq(
    <input type="submit" name="refresh" value="$text{'QUARANTINE_REFRESH_STATS'}"/>);
}

# Global quarantine data
print qq(<table>);
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

print qq(<p>$text{'QUARANTINE_PAGE_DESCRIPTION'}</p>);

print qq(<h1>$text{'QUARANTINE_CLEANING'}</h1>);

if (&clamav_get_acl ('quarantine_delete') == 1)
{
  print qq(<p><input type="submit" name="delete_all" value="$text{'PURGE_QUARANTINE_NOW'}"></p>);
}

print qq(<p>$text{'QUARANTINE_CRON_DESCRIPTION'}</p>);

print $msg;

@cron_line = &clamav_get_cron_settings ('purge');

print &clamav_cron_settings_table ($cron_line[1], $cron_line[4]);
if ($maxdays eq '')
{
  $maxdays = $cron_line[8];
}

# maxdays
print qq(<p>);
print qq($text{'DELETE_MAX_DAYS'} <input type="text" name="maxdays" size="2" value="$maxdays"> $text{'DAYS'});
print qq(</p>);

# npurge
$checked = ($#cron_line <= 0) ? ' CHECKED' : '';
print qq(<p>);
print qq(<input type="checkbox" id="nopurgeid" name="nopurge" value="on"$checked>);
print qq( <label for="nopurgeid">$text{'QUARANTINE_PURGE_NEVER'}</label>);
print qq(</p>);

print qq(<p>);
if (&clamav_get_acl ('quarantine_delete') == 1)
{
  print qq(<input type="submit" name="next" value="$text{'APPLY'}">);
}
print qq(</p>);

print qq(<h1>$text{'QUARANTINE_RESEARCH'}</h1>);

if (defined $in{'resended'})
{
  if (defined ($in{'errstr'}) && $in{'errstr'} ne '')
  {
    $msg = sprintf (qq(
      <b>$text{'MSG_ERROR_STATUS_RESEND'}</b>
      <p />
      <blockquote>
        <b>File</b>: %s<br>
        <b>Message</b>: %s
      </blockquote>
      ),
      &clamav_html_encode ($in{'errfile'}),
      &clamav_html_encode ($in{'errstr'})
    );
  }
  else
  {
    $msg = qq(<h3>$text{'MSG_SUCCESS_STATUS_RESEND'}</h3>);
  }
}
elsif (defined $in{'removed'})
{
  $msg = qq(<h3>$text{'MSG_SUCCESS_STATUS_REMOVE'}</h3>);
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
  {print qq(<tr><td $cb><b>$text{'VIRUS'}</b>:</td><td><input type="text" name="virus_name" value="$in{'virus_name'}"></td><td>&nbsp;</td></tr>)}
else
  {print qq(<input type="hidden" name="virus_name" value="">)}

print qq(<tr><td $cb><b>$text{'SENDER'}</b>:</td><td><input type="text" name="mail_from" value="$in{'mail_from'}"></td><td><input type="submit" value="$text{'SEARCH'}" name="search"></td></tr>
  <tr><td $cb><b>$text{'RECIPIENT'}</b>:</td><td><input type="text" name="mail_to" value="$in{'mail_to'}"></td><td>&nbsp;</td></tr>
  <tr><td $cb valign="top"><b>$text{'PERIOD'}</b>:</td><td colspan="2" nowrap valign="top">);
&clamav_get_period_chooser ($in{'day1'}, $in{'month1'}, $in{'year1'}, $in{'day2'}, $in{'month2'}, $in{'year2'});
print qq(
  </td></tr>
  </table>
  <p>
);

# if form submit, do the quarantine search
if ($in{'search'})
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
  
print qq(<hr>);
&footer("", $text{'RETURN_INDEX_MODULE'});

#!/usr/bin/perl

# Copyright (C) 2003-2019
# Emmanuel Saracco <emmanuel@esaracco.fr>
#
# GNU GENERAL PUBLIC LICENSE

use lib './lib';
use ClamavConstants;

require './clamav-lib.pl';
&clamav_check_acl ('quarantine_view');
&clamav_check_acl ('quarantine_resend');
&ReadParse ();

my ($_success, $_error) = ('', '');
my $smtp = (defined ($in{"smtp"}) && $in{"smtp"} ne '') ? $in{"smtp"} : '';
my $from = (defined ($in{"from"}) && $in{"from"} ne '') ? $in{"from"} : '';
my $to = (defined ($in{"to"}) && $in{"to"} ne '') ? $in{"to"} : '';
my $deleteafter = (defined ($in{"deleteafter"})) ? $in{"deleteafter"} : '';
my $notaspam = (defined ($in{"notaspam"})) ? $in{"notaspam"} : '';
my $default_tab = $in{'tab'};

if (!defined($in{'next'}) || ($smtp ne '' && !&smtphost_is_alive ($smtp)))
{
  &clamav_header ($text{'QUARANTINE_RESEND_PAGE_TITLE'});

  &clamav_quarantine_resend_check_config ();

  if ($smtp ne '' && !&smtphost_is_alive ($smtp))
  {
    $_error = sprintf (qq($text{'MSG_ERROR_SMTP_PING'}), $smtp);
  }

  if ($in{"newto"})
  {
    print qq(<p>$text{'QUARANTINE_RESEND_NEWTO_PAGE_DESCRIPTION'}</p>);

    print qq(<p><form method="POST" action="$scriptname">);
    print qq(<input type="hidden" name="newto" value="1"/>);
    print qq(<input type="hidden" name="tab" value="$default_tab"/>);
    printf qq(<input type="hidden" name="emails" value="%s"/>),
      ($in{'emails'}) ? &html_escape ($in{'emails'}) : 
      &clamav_join_from_url ("quarantine_file", 0);
    
    print qq(<table class="clamav keys-values">);
    print qq(<tr>);
    print qq(<td>$text{"FROM"}: </td>);
    printf qq(<td><input type="text" name="from" value="%s"></td>\n),
      &html_escape ($from);
    print qq(</tr>);
    print qq(<tr>);
    print qq(<td>$text{"TO"}: </td>);
    printf qq(<td><input type="text" name="to" value="%s"></td>\n),
      &html_escape ($to);
    print qq(</tr>);
    print qq(<tr>);
    print qq(<td>$text{"WITH_SMTP"}: </td>);
    printf qq(<td><input type="text" name="smtp" value="%s"></td>\n),
      &html_escape ($smtp);
    print qq(</tr>);
    print qq(</table>);

    # If spamassassin learning tool exists
    if (&has_command ('sa-learn'))
    {
      printf (qq(<p/><input type="checkbox" title="$text{'NOTASPAM_TOOLTIP'}" id="notaspam" value="1" name="notaspam"%s> <label title="$text{'NOTASPAM_TOOLTIP'}" for="notaspam">$text{'NOTASPAM'}</label>), ($notaspam) ? ' checked' : '');
    }

    printf (qq(<p/><input type="checkbox" id="deleteafter" value="1" name="deleteafter"%s> <label for="deleteafter">$text{'DELETEAFTER'}</label>), ($deleteafter) ? ' checked' : '');

    print qq(<p/><div><button type="submit" name="next" class="btn btn-success ui_form_end_submit"><i class="fa fa-fw fa-envelope"></i> <span>$text{'RESEND'}</span></button></div>);
    
    print qq(</form>);
  }

  &clamav_footer ("quarantine_main.cgi?tab=$default_tab",
    $text{'RETURN_QUARANTINE_LIST'}, $_success, $_error);
}
else
{
  foreach my $email (split (/&/, $in{'emails'}))
  {
    $email =~ s/^.*=//;

    # Learn as no spam
    if ($notaspam)
    {
      &clamav_learn_notaspam ($email);
    }

    $res = &clamav_resend_email ($email, $smtp, $from, $to);

    if ($res == NET_PING_KO)
    {
      &redirect ("quarantine_main.cgi?resended=1&tab=$default_tab".
        '&errstr='.&urlize(sprintf ($text{'MSG_ERROR_SMTP_PING'}, $smtp)).
	'&errfile='.&urlize($email));
    }
    # A error occured
    elsif ($res != OK)
    {
      &redirect ("quarantine_main.cgi?resended=1&tab=$default_tab".
       '&errstr='.&urlize($clamav_error).
       '&errfile='.&urlize($email));
    }
    # If all was ok
    elsif ($res == OK)
    {
      # Remove E-Mails files
      if ($deleteafter)
      {
        $res = &clamav_remove_email ($email);
      }
    }
  }

  &redirect ("quarantine_main.cgi?resended=1&tab=$default_tab");
}

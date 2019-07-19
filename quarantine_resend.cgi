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

my $smtp = (defined ($in{"smtp"}) && $in{"smtp"} ne '') ? $in{"smtp"} : '';
my $from = (defined ($in{"from"}) && $in{"from"} ne '') ? $in{"from"} : '';
my $to = (defined ($in{"to"}) && $in{"to"} ne '') ? $in{"to"} : '';
my $deleteafter = (defined ($in{"deleteafter"})) ? $in{"deleteafter"} : '';
my $notaspam = (defined ($in{"notaspam"})) ? $in{"notaspam"} : '';

if (!$in{'next'} || ($smtp ne '' && !&smtphost_is_alive ($smtp)))
{
  &header($text{'FORM_TITLE'}, "", undef, 1, 0);
  print "<hr>\n";

  &clamav_quarantine_resend_check_config ();

  print qq(<h1>$text{'QUARANTINE_RESEND_PAGE_TITLE'}</h1>\n);

  if ($smtp ne '' && !&smtphost_is_alive ($smtp))
  {
    printf qq(<b>$text{'MSG_ERROR_SMTP_PING'}</b>), $smtp;
  }

  if ($in{"newto"})
  {
    print qq(<p>$text{'QUARANTINE_RESEND_NEWTO_PAGE_DESCRIPTION'}</p>);

    print qq(<p><form method="POST" action="$scriptname">\n);
    print qq(<input type="hidden" name="newto" value="1">);
    printf qq(<input type="hidden" name="emails" value="%s">),
      ($in{'emails'}) ? &html_escape ($in{'emails'}) : 
      &clamav_join_from_url ("quarantine_file", 0);
    
    print qq(<table>);
    print qq(<tr>);
    print qq(<td $cb><b>$text{"FROM"}</b></td>\n);
    printf qq(<td><input type="text" name="from" value="%s"></td>\n),
      &html_escape ($from);
    print qq(</tr>);
    print qq(<tr>);
    print qq(<td $cb><b>$text{"TO"}</b></td>\n);
    printf qq(<td><input type="text" name="to" value="%s"></td>\n),
      &html_escape ($to);
    print qq(</tr>);
    print qq(<tr>);
    print qq(<td $cb><b>$text{"WITH_SMTP"}</b></td>\n);
    printf qq(<td><input type="text" name="smtp" value="%s"></td>\n),
      &html_escape ($smtp);
    print qq(</tr>);
    print qq(</table>);

    # If spamassassin learning tool exists
    if (&has_command ('sa-learn'))
    {
      printf qq(<p><input type="checkbox" title="$text{'NOTASPAM_TOOLTIP'}" id="notaspam" value="1" name="notaspam"%s> <label title="$text{'NOTASPAM_TOOLTIP'}" for="notaspam">$text{'NOTASPAM'}</label></p>), ($notaspam) ? ' checked' : '';
      print qq(<p />);
    }

    printf qq(<p><input type="checkbox" id="deleteafter" value="1" name="deleteafter"%s> <label for="deleteafter">$text{'DELETEAFTER'}</label></p>), ($deleteafter) ? ' checked' : '';

    print qq(<p><input type="submit" name="next" value="$text{'RESEND'}"></p>\n);
    
    print qq(</form>);
  }

  print qq(<hr);
  &footer ("quarantine_main.cgi", $text{'RETURN_QUARANTINE_LIST'});
}
else
{
  foreach my $email (split (/&/, $in{"emails"}))
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
      &redirect ("/$module_name/quarantine_main.cgi?resended=1&" . 
        "&errstr=" . 
	&urlize (sprintf ($text{'MSG_ERROR_SMTP_PING'}, $smtp)) . 
	"&errfile=" . &urlize ($email));
    }
    # A error occured
    elsif ($res != OK)
    {
      &redirect ("/$module_name/quarantine_main.cgi?resended=1&" . 
        "&errstr=" . &urlize ($clamav_error) . 
	"&errfile=" . &urlize ($email));
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

  &redirect ("/$module_name/quarantine_main.cgi?resended=1");
}

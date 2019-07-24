#!/usr/bin/perl

# Copyright (C) 2003-2019
# Emmanuel Saracco <emmanuel@esaracco.fr>
#
# GNU GENERAL PUBLIC LICENSE

require './clamav-lib.pl';
&clamav_check_acl ('clamav_remote_control');
&ReadParse ();

my ($_success, $_error) = ('', '');
my $next = defined($in{'next'});
my $scandir = ($next && $in{'what'} ne '');
my $host = $in{'host'};
my $port = $in{'port'};
my $action = $in{'action'};
my $arg = $in{'arg'} ? $in{'arg'} : '';

&clamav_header ($text{'LINK_REMOTE_CONTROL'});

if (!$arg && &clamav_remote_actions_take_arg ($action))
{
  $_error = $text{'MSG_ERROR_TAKE_ARG'};
}
elsif ($arg && !&clamav_remote_actions_take_arg ($action))
{
  $_error = $text{'MSG_ERROR_TAKE_NO_ARG'};
}

print qq(<p>$text{'REMOTE_CONTROL_DESCRIPTION'}</p>);

$next = undef if ($_error ne '');

print qq(<form method="POST" action="$scriptname">);

&clamav_display_remote_actions ($host, $port, $action, $arg);

print qq(<p/><div><button type="submit" name="next" class="btn btn-success ui_form_end_submit"><i class="fa fa-fw fa-arrow-right"></i> <span>$text{'SEND'}</span></button></div><p/>);

if ($next)
{
  my $msg = &clamav_send_remote_action ($host, $port, $action, $arg);

  if (!defined ($msg))
  {
    $_error = $text{'MSG_ERROR_NO_CONNECTION'};
  }
  elsif ($msg eq '')
  {
    $_error = $text{'MSG_ERROR_NO_ANSWER'};
  }
  else
  {
    $msg =~ s/\n/<br>/g;
    print qq(<p><b>$text{'DAEMON_ANSWER'}:</b></p>);
    print qq(<div class="raw-output">$msg</div>);
  }
}

print qq(</form>);

&clamav_footer ('', $text{'RETURN_INDEX_MODULE'}, $_success, $_error);

#!/usr/bin/perl

# Copyright (C) 2003-2019
# Emmanuel Saracco <emmanuel@esaracco.fr>
#
# GNU GENERAL PUBLIC LICENSE

require './clamav-lib.pl';
&clamav_check_acl ('clamav_remote_control');
&ReadParse ();

my $next = defined($in{'next'});
my $scandir = ($next && $in{'what'} ne '');
my $host = $in{'host'};
my $port = $in{'port'};
my $action = $in{'action'};
my $arg = $in{'arg'} ? $in{'arg'} : '';
my $msg = '';

&clamav_header ($text{'LINK_REMOTE_CONTROL'});

if (!$arg && &clamav_remote_actions_take_arg ($action))
{
  $msg = $text{'MSG_ERROR_TAKE_ARG'};
}
elsif ($arg && !&clamav_remote_actions_take_arg ($action))
{
  $msg = $text{'MSG_ERROR_TAKE_NO_ARG'};
}

print qq(<p>$text{'REMOTE_CONTROL_DESCRIPTION'}</p>);

if ($msg ne '')
{
  print qq(<p><b>$msg</b></p>);
  $next = 0;
}

print qq(<form method="POST" action="$scriptname">);

&clamav_display_remote_actions ($host, $port, $action, $arg);

print qq(<p/><button type="submit" name="next" class="btn btn-success">$text{'SEND'}</button><p/>);

if ($next)
{
  my $msg = &clamav_send_remote_action ($host, $port, $action, $arg);

  if (!defined ($msg))
  {
    print qq(<b>$text{'MSG_ERROR_NO_CONNECTION'}</b>);
  }
  elsif ($msg eq '')
  {
    print qq(<b>$text{'MSG_ERROR_NO_ANSWER'}</b>);
  }
  else
  {
  $msg =~ s/\n/<br>/g;
    print qq(<p><b>ClamAV daemon answer is:</b></p>);
    print qq(<div class="raw-output">$msg</div>);
  }
}

print qq(</form>);

print qq(<hr>);
&footer("", $text{'RETURN_INDEX_MODULE'});

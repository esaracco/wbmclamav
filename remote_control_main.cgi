#!/usr/bin/perl

# Copyright (C) 2003-2008
# Emmanuel Saracco <emmanuel@esaracco.fr>
#
# GNU GENERAL PUBLIC LICENSE

require './clamav-lib.pl';
&clamav_check_acl ('clamav_remote_control');
&ReadParse ();

my $scandir = ($in{'next'} && $in{'what'} ne '');
my $host = $in{'host'};
my $port = $in{'port'};
my $action = $in{'action'};
my $arg = $in{'arg'} ? $in{'arg'} : '';
my $next = $in{'next'};
my $msg = '';

if (&clamav_remote_actions_take_arg ($action) && !$arg)
{
  $msg = $text{'MSG_ERROR_TAKE_ARG'};
}
elsif (!&clamav_remote_actions_take_arg ($action) && $arg)
{
  $msg = $text{'MSG_ERROR_TAKE_NO_ARG'};
}

&header ($text{'FORM_TITLE'}, '', undef, 1, 0, undef, undef,
  '<link rel="stylesheet" type="text/css" href="css/styles.css"/>');
print "<hr>\n";

print qq(<h1>$text{'REMOTE_CONTROL_TITLE'}</h1>);
print qq(<p>$text{'REMOTE_CONTROL_DESCRIPTION'}</p>);

if ($msg ne '')
{
  print qq(<p><b>$msg</b></p>);
  $next = '';
}

print qq(<form method="POST" action="$scriptname">);

&clamav_display_remote_actions ($host, $port, $action, $arg);

print qq(<p><input type="submit" name="next" value="$text{'SEND'}"></p>);

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
    print qq(<p><b>ClamAV daemon answer is:</b></p>);
    print qq(<pre style="background:silver">$msg</pre>);
  }
}

print qq(</form>);

print qq(<hr>);
&footer("", $text{'RETURN_INDEX_MODULE'});

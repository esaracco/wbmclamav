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

&header($text{'FORM_TITLE'}, "", undef, 1, 0);
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
  my $h = 0;
  my $error = '';
  my $line = '';
  
  alarm (15);
  if (&open_socket ($host, $port, $h, \$error))
  {
    alarm (0);
    printf $h "$action%s\r\n", ($arg) ? " $arg" : '';

    print qq(<p><h2>$text{'SERVER_RESPONSE'}</h2></p>);

    select (STDOUT);
    print qq(<pre style="background:silver;">);
    while (<$h>) {print}
    print qq(</pre>);
    close ($h);
  }
  else
  {
    print qq(<b>$text{'MSG_ERROR_NO_RESPONSE'}</b>);
  }
}

print qq(</form>);

print qq(<hr>);
&footer("", $text{'RETURN_INDEX_MODULE'});

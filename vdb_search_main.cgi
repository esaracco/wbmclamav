#!/usr/bin/perl

# Copyright (C) 2003-2019
# Emmanuel Saracco <emmanuel@esaracco.fr>
#
# GNU GENERAL PUBLIC LICENSE

require './clamav-lib.pl';
&clamav_check_acl ('database_search_search');
&ReadParse ();

&clamav_vdb_preprocess_inputs (\%in);

&clamav_header ();

$search = (($in{'search'} && ($in{'prefix0'} || $in{'virus'})) || $in{'all'});

print qq(<h1>$text{'VDB_SEARCH_TITLE'}</h1>);
printf "<p><i>$text{'VDB_SEARCH_VIRUSES_COUNT'}</i> ",
  &clamav_get_db_viruses_count ();
print qq( [<a href="/$module_name/updates_main.cgi">$text{'VDB_SEARCH_UPDATE_DB'}</a>]</p>);
print qq(<p>$text{'VDB_SEARCH_DESCRIPTION'}</p>);

if ($in{'search'} && !$in{'prefix0'} && !$in{'virus'})
{
  print qq(<p><b>$text{'MSG_VIRUS_NAME'}</b></p>);
}

print qq(<form method="POST" action="$scriptname">);

print &clamav_display_combos_viruses_prefixes ($in{'prefix0'}, $in{'prefix1'});

# search string input
print qq(
  <input type="text" name="virus" value="$in{'virus'}"/>
  <input type="submit" name="search" value="$text{'SEARCH'}">
);

# strict match check box
$checked = ($in{'strict'} eq 'on') ? ' CHECKED' : '';
print qq(<p/><p><input id="strict" type="checkbox" name="strict" value="on"$checked> );
print qq(<label for="strict">$text{'SEARCH_STRICT'}</label>);

# case sensitive check box
$checked = ($in{'case'} eq 'on') ? ' CHECKED' : '';
print qq( <input id="case" type="checkbox" name="case" value="on"$checked/> );
print qq(<label for="case">$text{'SEARCH_CASE_SENSITIVE'}</label></p>);

# sort result check box
$checked = ($in{'sort'} eq 'on') ? ' CHECKED' : '';
print qq(<p><input id="sort" type="checkbox" name="sort" value="on"$checked> );
print qq(<label for="sort">$text{'SEARCH_SORT_RESULT'}</label></p>);

print qq(<input type="submit" name="all" value="$text{'DISPLAY_ALL'}"></p>);

print qq(</form>);

if ($search)
{
  $in{'virus'} = '' if ($in{'all'});

  print qq(<p>);
  &clamav_vdb_search (\%in);
  print qq(</p>);
}

print qq(<hr/>);
&footer('', $text{'RETURN_INDEX_MODULE'});

#!/usr/bin/perl

# Copyright (C) 2003-2019
# Emmanuel Saracco <emmanuel@esaracco.fr>
#
# GNU GENERAL PUBLIC LICENSE

require './clamav-lib.pl';
&clamav_check_acl ('database_search_search');
&ReadParse ();

my ($_success, $_error) = ('', '');

&clamav_vdb_preprocess_inputs (\%in);

&clamav_header ($text{'LINK_VDB_SEARCH'});

$search = (defined($in{'search'}) && ($in{'prefix0'} || $in{'virus'}));

printf ("<p><i>$text{'VDB_SEARCH_VIRUSES_COUNT'}</i> ",
  &clamav_get_db_viruses_count ());
print qq( [<a href="updates_main.cgi">$text{'VDB_SEARCH_UPDATE_DB'}</a>]</p>);
print qq(<p>$text{'VDB_SEARCH_DESCRIPTION'}</p>);

if (defined($in{'search'}) && !$in{'prefix0'} && !$in{'virus'})
{
  $_error = $text{'MSG_VIRUS_NAME'};
}

print qq(<form method="POST" action="$scriptname">);

print &clamav_display_combos_viruses_prefixes ($in{'prefix0'}, $in{'prefix1'});

# search string input
print qq(<input type="text" name="virus" value="$in{'virus'}"/>);

# strict match check box
$checked = ($in{'strict'} eq 'on') ? ' checked="checked"' : '';
print qq(<p/><p><input id="strict" type="checkbox" name="strict" value="on"$checked> );
print qq(<label for="strict">$text{'SEARCH_STRICT'}</label></p>);

# case sensitive check box
$checked = ($in{'case'} eq 'on') ? ' checked="checked"' : '';
print qq( <input id="case" type="checkbox" name="case" value="on"$checked/> );
print qq(<label for="case">$text{'SEARCH_CASE_SENSITIVE'}</label></p>);

# sort result check box
$checked = ($in{'sort'} eq 'on') ? ' checked="checked"' : '';
print qq(<p><input id="sort" type="checkbox" name="sort" value="on"$checked> );
print qq(<label for="sort">$text{'SEARCH_SORT_RESULT'}</label></p>);

print qq(<div><button type="submit" name="search" class="btn btn-success ui_form_end_submit"><i class="fa fa-fw fa-search"></i> <span>$text{'SEARCH'}</span></button></div>);

print qq(</form>);

if ($search)
{
  print qq(<p>);
  &clamav_vdb_search (\%in);
  print qq(</p>);
}

&clamav_footer ('', $text{'RETURN_INDEX_MODULE'}, $_success, $_error);

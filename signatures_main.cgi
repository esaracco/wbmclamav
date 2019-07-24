#!/usr/bin/perl

# Copyright (C) 2003-2019
# Emmanuel Saracco <emmanuel@esaracco.fr>
#
# GNU GENERAL PUBLIC LICENSE

require './clamav-lib.pl';
&clamav_check_acl ('signature_use');
&ReadParse ();

my ($_success, $_error) = ('', '');

&clamav_header ($text{'LINK_SIGNATURES'});

&clamav_signatures_check_config ();

print qq(<form method="POST" action="signatures_1step.cgi" enctype="multipart/form-data">);
print qq(<input type="hidden" name="main" value="1">);

print qq(<p>$text{'SIGNATURES_DESCRIPTION'}</p>);

print qq(<h2>$text{'SIGNATURES_FIRST_STEP'}</h2>);

$_error = $text{'MSG_ERROR_FILE_UPLOAD'} if $in{'error'};

print qq(<input type="file" name="upload" size="30"/>);

print qq(<p/><div><button type="submit" name="next" class="btn btn-success ui_form_end_submit" style=><i class="fa fa-fw fa-upload"></i> <span>$text{'UPLOAD'}</span></button></div>);

print qq(</form>);

&clamav_footer ('', $text{'RETURN_INDEX_MODULE'}, $_success, $_error);

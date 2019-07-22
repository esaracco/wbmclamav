#!/usr/bin/perl

# Copyright (C) 2003-2019
# Emmanuel Saracco <emmanuel@esaracco.fr>
#
# GNU GENERAL PUBLIC LICENSE

require './clamav-lib.pl';
&clamav_check_acl ('signature_use');
&ReadParse ();

&clamav_header ($text{'LINK_SIGNATURES'});

&clamav_signatures_check_config ();

print qq(<form method="POST" action="signatures_1step.cgi" enctype="multipart/form-data">);
print qq(<input type="hidden" name="main" value="1">);

print qq(<p>$text{'SIGNATURES_DESCRIPTION'}</p>);

print qq(<h2>$text{'SIGNATURES_FIRST_STEP'}</h2>);

print qq(<p>$text{'MSG_ERROR_FILE_UPLOAD'}</p>) if $in{'error'};

print qq(<input type="file" name="upload" size="30">);

print qq(<p/><button type="submit" name="next" class="btn btn-success">$text{'UPLOAD'}</button>);

print qq(</form>);

print qq(<hr>);
&footer("", $text{'RETURN_INDEX_MODULE'});
